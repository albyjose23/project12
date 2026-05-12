require_relative "boot"

require "rails/all"
require "tmpdir"

begin
  require "dotenv"

  app_root = File.expand_path("..", __dir__)
  dotenv_files = [
    ".env.#{ENV.fetch("RAILS_ENV", "development")}.local",
    (".env.local" unless ENV.fetch("RAILS_ENV", "development") == "test"),
    ".env.#{ENV.fetch("RAILS_ENV", "development")}",
    ".env"
  ].compact.map { |file| File.join(app_root, file) }

  Dotenv.load(*dotenv_files)
rescue LoadError
  warn "dotenv gem is unavailable; skipping .env loading"
end

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module QpaperApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    if Gem.win_platform?
      config.paths["log"] = [File.join(Dir.tmpdir, "qpaper_app-#{Rails.env}.log")]
    end

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
