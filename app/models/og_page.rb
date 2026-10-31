OgPage = Data.define(:key, :title, :headline, :description, :path, :background) do
  def self.find(key) = all[key.to_s]

  def self.all
    @all ||= YAML.load_file(Rails.root.join("config/og_pages.yml")).to_h do |key, attrs|
      [ key, new(key: key, **attrs.symbolize_keys) ]
    end.freeze
  end
end
