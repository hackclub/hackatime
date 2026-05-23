module UserThemeConfiguration
  extend ActiveSupport::Concern

  DEFAULT_THEME = "rose".freeze
  THEME_OPTIONS = YAML.safe_load_file(Rails.root.join("config/themes.yml"))
                      .map { |t| t.deep_symbolize_keys }
                      .freeze
  THEME_OPTION_BY_VALUE = THEME_OPTIONS.index_by { |theme| theme[:value] }.freeze

  class_methods do
    def theme_options = THEME_OPTIONS.map(&:deep_dup)
    def theme_metadata(name) = THEME_OPTION_BY_VALUE[name.to_s] || THEME_OPTION_BY_VALUE[DEFAULT_THEME]
  end
end
