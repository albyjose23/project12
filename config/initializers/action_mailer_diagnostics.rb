if defined?(ActionMailer)
  Rails.application.config.after_initialize do
    mailer_config = Rails.application.config.action_mailer
    smtp_settings = mailer_config.smtp_settings.to_h.deep_dup

    if smtp_settings[:password].present?
      smtp_settings[:password] = "[FILTERED]"
    end

    Rails.logger.info(
      "[ActionMailer] env=#{Rails.env} " \
      "delivery_method=#{mailer_config.delivery_method.inspect} " \
      "perform_deliveries=#{mailer_config.perform_deliveries.inspect} " \
      "raise_delivery_errors=#{mailer_config.raise_delivery_errors.inspect} " \
      "default_url_options=#{mailer_config.default_url_options.inspect} " \
      "smtp_settings=#{smtp_settings.inspect} " \
      "env_presence=#{{
        smtp_username: ENV["SMTP_USERNAME"].present?,
        smtp_password: ENV["SMTP_PASSWORD"].present?,
        mailer_from_email: ENV["MAILER_FROM_EMAIL"].present?,
        app_host: ENV["APP_HOST"].present?
      }.inspect}"
    )
  end

  ActiveSupport::Notifications.subscribe("deliver.action_mailer") do |_name, started, finished, _id, payload|
    mail = payload[:mail]
    duration_ms = ((finished - started) * 1000).round(1)
    recipients = Array(mail&.to).join(", ")
    subject = mail&.subject.to_s

    if (exception = payload[:exception_object])
      Rails.logger.error(
        "[ActionMailer] delivery failed mailer=#{payload[:mailer]} action=#{payload[:action]} " \
        "to=#{recipients.inspect} subject=#{subject.inspect} duration_ms=#{duration_ms} " \
        "error_class=#{exception.class} error_message=#{exception.message}"
      )
      Rails.logger.error(exception.backtrace.take(15).join("\n")) if exception.backtrace.present?
    else
      Rails.logger.info(
        "[ActionMailer] delivered mailer=#{payload[:mailer]} action=#{payload[:action]} " \
        "to=#{recipients.inspect} subject=#{subject.inspect} duration_ms=#{duration_ms}"
      )
    end
  end
end
