module HeartbeatRemapper
  class AuthoritativeExtension
    ID = "language/authoritative-extension/v1"
    WRITABLE_FIELDS = %i[language].freeze
    EXTENSIONS = %w[.cjs .jinja .luau .postcss].freeze

    def self.call(attributes)
      extension = File.extname(attributes[:entity].to_s).downcase
      return {} unless EXTENSIONS.include?(extension)

      { language: LanguageUtils.detect_from_extension(attributes[:entity]) }
    end
  end
end
