module LanguageUtils
  DEFAULT_COLOR = "#888888"

  def self.data
    @data ||= begin
      base = YAML.load_file(Rails.root.join("config/languages.yml"))
      custom_path = Rails.root.join("config/languages_custom.yml")
      custom = File.exist?(custom_path) ? YAML.load_file(custom_path) : {}
      merged = base.deep_merge(custom) { |_key, base_val, custom_val|
        base_val.is_a?(Array) && custom_val.is_a?(Array) ? base_val | custom_val : custom_val
      }
      custom.each do |name, info|
        next unless info.key?("extensions")
        merged_extensions = merged.dig(name, "extensions") || []
        merged_extensions.each do |ext|
          merged.each do |other_name, other_info|
            next if other_name == name
            other_info["extensions"]&.delete(ext)
          end
        end
      end
      merged
    end
  end

  # Builds a lookup from `info[key]` values (downcased) → canonical language name.
  # Also includes the canonical name itself when `include_name_as_key` is true.
  def self.build_lookup(key, include_name_as_key: false)
    map = {}
    data.each do |name, info|
      map[name.downcase] = name if include_name_as_key
      (info[key] || []).each { |v| map[v.downcase] = name }
    end
    map
  end
  private_class_method :build_lookup

  def self.alias_map = @alias_map ||= build_lookup("aliases", include_name_as_key: true)
  def self.extension_map = @extension_map ||= build_lookup("extensions")
  def self.filename_map = @filename_map ||= build_lookup("filenames")

  # Resolve a raw language string to its canonical name.
  def self.find_name(raw)
    return nil if raw.blank?
    key = raw.downcase
    alias_map[key] || data.keys.find { |name| name.downcase == key }
  end

  def self.blank_or_unknown?(raw) = raw.blank? || raw.to_s.strip.casecmp("unknown").zero?
  def self.detect_from_filename(entity) = entity.present? ? filename_map[File.basename(entity).downcase] : nil

  def self.detect_from_extension(entity)
    return nil if entity.blank?
    ext = File.extname(entity).downcase
    ext.blank? ? nil : extension_map[ext]
  end

  def self.detect_from_entity(entity) = detect_from_filename(entity) || detect_from_extension(entity)
  def self.fill_missing_language(raw, entity:) = blank_or_unknown?(raw) ? detect_from_entity(entity) : raw

  # Canonical display name: "js" → "JavaScript", "cpp" → "C++"
  def self.display_name(raw) = raw.blank? ? "Unknown" : (find_name(raw) || raw)

  # Hex color string: "Ruby" → "#701516"
  def self.color(raw)
    name = find_name(raw)
    name ? (data.dig(name, "color") || DEFAULT_COLOR) : DEFAULT_COLOR
  end

  # { "Ruby" => "#701516", "Python" => "#3572A5", ... }
  def self.colors_for(language_names) = language_names.index_with { |name| color(name) }
end
