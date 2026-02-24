module LanguageUtils
  DEFAULT_COLOR = "#888888"

  def self.data
    @data ||= YAML.load_file(Rails.root.join("config/languages.yml"))
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
