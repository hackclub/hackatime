module HeartbeatRemapper
  class AuthoritativeFilename
    ID = "language/authoritative-filename/v1"
    WRITABLE_FIELDS = %i[language].freeze
    LANGUAGES = [ "Dotenv", "Git Attributes", "Ignore List", "Option List" ].freeze

    def self.call(attributes)
      language = LanguageUtils.detect_from_filename(attributes[:entity])
      return {} unless LANGUAGES.include?(language)

      { language: }
    end
  end
end
