module HeartbeatRemapper
  class AutoDetected
    ID = "language/auto-detected/v1"
    WRITABLE_FIELDS = %i[language].freeze

    def self.call(attributes)
      return {} unless attributes[:language] == "AUTO_DETECTED"

      { language: LanguageUtils.detect_unambiguous_from_entity(attributes[:entity]) || "Unknown" }
    end
  end
end
