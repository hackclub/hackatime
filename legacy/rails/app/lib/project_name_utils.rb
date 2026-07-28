module ProjectNameUtils
  module_function

  def broken?(project_key, display_name = project_key.presence || "Unknown")
    key = project_key.to_s
    name = display_name.to_s

    key.blank? || name.downcase == "unknown" || key.match?(/<<.*>>/) || name.match?(/<<.*>>/) || key.match?(/[\r\n]/)
  end
end
