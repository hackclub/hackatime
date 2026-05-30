module ApplicationHelper
  def current_theme
    theme_name = current_user&.theme
    return User::DEFAULT_THEME if theme_name.blank?
    User.themes.key?(theme_name) ? theme_name : User::DEFAULT_THEME
  end

  def current_theme_color_scheme = User.theme_metadata(current_theme).fetch(:color_scheme, "dark")
  def current_theme_color = User.theme_metadata(current_theme).fetch(:theme_color, "#c8394f")

  ADMIN_TOOL_ROLES = {
    admin_tool: %w[admin superadmin ultraadmin],
    superadmin_tool: %w[superadmin ultraadmin],
    ultraadmin_tool: %w[ultraadmin],
    viewer_tool: %w[viewer]
  }.freeze

  ADMIN_TOOL_ROLES.each do |name, roles|
    css_class = name.to_s.tr("_", "-")
    define_method(name) do |class_name = "", element = "div", **options, &block|
      return unless current_user && roles.include?(current_user.admin_level)
      concat content_tag(element, class: "#{css_class} #{class_name}", **options, &block)
    end
  end

  def dev_tool(class_name = "", element = "div", **options, &block)
    return unless Rails.env.development?
    concat content_tag(element, class: "dev-tool #{class_name}", **options, &block)
  end

  def country_to_emoji(country_code)
    return "" unless country_code.present?
    code_path = country_code.upcase.chars.map { |c| (0x1F1E6 + c.ord - "A".ord).to_s(16) }.join("-")
    image_tag(
      "https://cdn.jsdelivr.net/gh/twitter/twemoji@latest/assets/svg/#{code_path}.svg",
      alt: "#{country_code} flag", class: "inline-block w-5 h-5 align-middle", loading: "lazy"
    )
  end

  def digital_time(time)
    h, m, s = time.to_i.divmod(3600).then { |h, r| [ h, *r.divmod(60) ] }
    [ h, m, s ].map { |part| part.to_s.rjust(2, "0") }.join(":")
  end

  def short_time_simple(time)
    hours = time.to_i / 3600
    minutes = (time.to_i % 3600) / 60
    return "0m" if hours.zero? && minutes.zero?
    [ hours.positive? && "#{hours}h", minutes.positive? && "#{minutes}m" ].select { |p| p }.join(" ")
  end

  def short_time_detailed(time)
    # ie. 5h 10m 10s / 10m 10s / 10m
    h, m, s = time.to_i.divmod(3600).then { |h, r| [ h, *r.divmod(60) ] }
    [ h.positive? && "#{h}h", m.positive? && "#{m}m", s.positive? && "#{s}s" ].select { |p| p }.join(" ")
  end

  CLOCK_EMOJIS = %w[🕛 🕧 🕐 🕜 🕑 🕝 🕒 🕞 🕓 🕟 🕔 🕠 🕕 🕡 🕖 🕢 🕗 🕣 🕘 🕤 🕙 🕥 🕚 🕦].freeze

  def time_in_emoji(duration) = CLOCK_EMOJIS[(duration.to_i / 1800) % CLOCK_EMOJIS.length]

  def human_interval_name(key, from: nil, to: nil)
    if key.present? && Heartbeat.respond_to?(:humanize_range) && Heartbeat::RANGES.key?(key.to_sym)
      Heartbeat.humanize_range(Heartbeat::RANGES[key.to_sym][:calculate].call)
    elsif from.present? && to.present?
      "#{from} to #{to}"
    else
      "All Time"
    end
  end

  EDITOR_DISPLAY_NAMES = {
    "vscode" => "VSCode", "vs code" => "VSCode",
    "pycharm" => "PyCharm",
    "intellij" => "IntelliJ IDEA", "intellijidea" => "IntelliJ IDEA", "intellij idea" => "IntelliJ IDEA",
    "webstorm" => "WebStorm", "phpstorm" => "PhpStorm", "datagrip" => "DataGrip",
    "ktexteditor" => "Kate", "android studio" => "Android Studio", "visual studio" => "Visual Studio",
    "sublime text" => "Sublime Text", "iterm2" => "iTerm2", "rubymine" => "RubyMine",
    "opencode" => "OpenCode", "claudecode" => "Claude Code", "claude code" => "Claude Code",
    "zoom.us" => "Zoom", "windowspowershell" => "PowerShell",
    "goland" => "GoLand", "rustrover" => "RustRover"
  }.freeze

  OS_DISPLAY_NAMES = {
    "darwin" => "macOS", "macos" => "macOS", "mac" => "macOS",
    "wsl" => "WSL", "mozilla" => "Firefox", "vscode" => "VSCode"
  }.freeze

  def display_editor_name(editor)
    return "Unknown" if editor.blank?
    EDITOR_DISPLAY_NAMES[editor.downcase] || editor.capitalize
  end

  def display_os_name(os)
    return "Unknown" if os.blank?
    OS_DISPLAY_NAMES[os.downcase] || os.capitalize
  end

  def display_language_name(language) = LanguageUtils.display_name(language)

  def shorten_file_path(entity)
    return entity if entity.blank?
    parts = entity.split("/")
    parts.length <= 3 ? entity : "#{parts.first}/…/#{parts.last(2).join("/")}"
  end

  def safe_asset_path(asset_name, fallback: nil)
    asset_path(asset_name)
  rescue StandardError
    fallback.present? ? asset_path(fallback) : asset_name
  end
end
