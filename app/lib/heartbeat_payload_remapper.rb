class HeartbeatPayloadRemapper
  ZED_PROJECT_FIRST_VERSION = Gem::Version.new("0.162.0")
  MACOS_WAKATIME_ZED_FIX_VERSION = Gem::Version.new("5.28.5-alpha.1")
  AUTHORITATIVE_LANGUAGE_EXTENSIONS = %w[.luau].freeze

  def self.remap_fields(attributes, user_agent: attributes[:user_agent])
    attributes = attributes.dup
    remap_macos_wakatime_zed_fields!(attributes, user_agent:)
    attributes
  end

  def self.remap_language(attributes)
    attributes = attributes.dup
    attributes[:language] = authoritative_language(attributes[:entity]) ||
      legacy_language(attributes[:language], entity: attributes[:entity])
    attributes
  end

  # Kept for import deduplication against hashes stored before authoritative
  # language corrections were introduced.
  def self.legacy_language(raw, entity:)
    blank_or_unknown?(raw) ? LanguageUtils.detect_from_entity(entity) : raw
  end

  def self.remap_macos_wakatime_zed_fields!(attributes, user_agent:)
    return unless attributes[:type] == "app"

    zed_version = product_version(user_agent, "Zed")
    macos_wakatime_version = product_version(user_agent, "macos-wakatime")
    return unless zed_version && macos_wakatime_version
    return unless zed_version >= ZED_PROJECT_FIRST_VERSION
    return unless macos_wakatime_version < MACOS_WAKATIME_ZED_FIX_VERSION

    attributes[:entity], attributes[:project] = attributes[:project], attributes[:entity]
  end
  private_class_method :remap_macos_wakatime_zed_fields!

  def self.authoritative_language(entity)
    return if entity.blank?
    return unless AUTHORITATIVE_LANGUAGE_EXTENSIONS.include?(File.extname(entity).downcase)

    LanguageUtils.detect_from_extension(entity)
  end
  private_class_method :authoritative_language

  def self.blank_or_unknown?(raw) = raw.blank? || raw.to_s.strip.casecmp("unknown").zero?
  private_class_method :blank_or_unknown?

  def self.product_version(user_agent, product)
    version = user_agent.to_s.match(/(?:\A|\s)#{Regexp.escape(product)}\/([^\s]+)/i)&.captures&.first
    Gem::Version.new(version&.split("+")&.first)
  rescue ArgumentError
    nil
  end
  private_class_method :product_version
end
