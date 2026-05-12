env_files = [
  Rails.root.join(".env"),
  Rails.root.join(".env.local"),
  Rails.root.join(".env.#{Rails.env}"),
  Rails.root.join(".env.#{Rails.env}.local")
]

env_files.each do |path|
  next unless File.file?(path)

  File.foreach(path) do |line|
    stripped = line.strip
    next if stripped.empty? || stripped.start_with?("#") || !stripped.include?("=")

    key, value = stripped.split("=", 2)
    next if key.blank?

    cleaned_value = value.to_s.strip
    cleaned_value = cleaned_value[1..-2] if cleaned_value.start_with?('"') && cleaned_value.end_with?('"')
    cleaned_value = cleaned_value[1..-2] if cleaned_value.start_with?("'") && cleaned_value.end_with?("'")

    ENV[key] ||= cleaned_value
  end
end
