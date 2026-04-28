module LanguageUtils
  DEFAULT_COLOR = "#888888"

  def self.data
    @data ||= begin
      base = YAML.load_file(Rails.root.join("config/languages.yml"))
      custom_path = Rails.root.join("config/languages_custom.yml")
      custom = File.exist?(custom_path) ? YAML.load_file(custom_path) : {}
      base.deep_merge(custom)
    end
  end

  # Builds a lookup from lowercase name/alias → canonical language name.
  def self.alias_map
    @alias_map ||= begin
      map = {}
      data.each do |name, info|
        map[name.downcase] = name
        (info["aliases"] || []).each { |a| map[a.downcase] = name }
      end
      map
    end
  end

  # Resolve a raw language string to its canonical name.
  # Tries exact name match first, then aliases.
  def self.find_name(raw)
    return nil if raw.blank?

    key = raw.downcase
    canonical = alias_map[key]
    return canonical if canonical

    # Try case-insensitive match against canonical names
    data.keys.find { |name| name.downcase == key }
  end

  # Builds a lookup from file extension → canonical language name.
  def self.extension_map
    @extension_map ||= begin
      map = {}
      data.each do |name, info|
        (info["extensions"] || []).each { |ext| map[ext.downcase] = name }
      end
      map
    end
  end

  def self.filename_map
    @filename_map ||= begin
      map = {}
      data.each do |name, info|
        (info["filenames"] || []).each { |filename| map[filename.downcase] = name }
      end
      map
    end
  end

  def self.blank_or_unknown?(raw)
    raw.blank? || raw.to_s.strip.casecmp("unknown").zero?
  end

  def self.detect_from_filename(entity)
    return nil if entity.blank?

    filename_map[File.basename(entity).downcase]
  end

  # Detect language from a file entity's extension.
  def self.detect_from_extension(entity)
    return nil if entity.blank?
    ext = File.extname(entity).downcase
    return nil if ext.blank?
    extension_map[ext]
  end

  def self.detect_from_entity(entity)
    detect_from_filename(entity) || detect_from_extension(entity)
  end

  def self.fill_missing_language(raw, entity:)
    return raw unless blank_or_unknown?(raw)

    detect_from_entity(entity)
  end

  # Canonical display name: "js" → "JavaScript", "cpp" → "C++"
  def self.display_name(raw)
    return "Unknown" if raw.blank?

    find_name(raw) || raw
  end

  # Hex color string: "Ruby" → "#701516"
  def self.color(raw)
    name = find_name(raw)
    return DEFAULT_COLOR unless name

    data.dig(name, "color") || DEFAULT_COLOR
  end

  # { "Ruby" => "#701516", "Python" => "#3572A5", ... }
  def self.colors_for(language_names)
    language_names.index_with { |name| color(name) }
  end
end
