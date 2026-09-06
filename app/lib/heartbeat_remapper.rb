module HeartbeatRemapper
  class InvalidRule < ArgumentError; end

  WRITABLE_FIELDS = %i[language].freeze

  Result = Data.define(:attributes, :rule_ids)

  REGISTRY = [ AuthoritativeFilename, AuthoritativeExtension, AutoDetected ].freeze

  def self.call(attributes, registry: REGISTRY)
    corrected = attributes.to_h.deep_symbolize_keys.deep_dup
    applied = []

    registry.each do |rule|
      writable_fields = Array(rule::WRITABLE_FIELDS).map(&:to_sym)
      invalid_fields = writable_fields - WRITABLE_FIELDS
      if invalid_fields.any?
        raise InvalidRule, "#{rule} declares forbidden writable fields: #{invalid_fields.join(", ")}"
      end

      changes = rule.call(corrected.deep_dup).to_h.deep_symbolize_keys
      undeclared_fields = changes.keys - writable_fields
      if undeclared_fields.any?
        raise InvalidRule, "#{rule} changed undeclared fields: #{undeclared_fields.join(", ")}"
      end

      effective_changes = changes.reject { |field, value| corrected[field] == value }
      next if effective_changes.empty?

      corrected.merge!(effective_changes)
      applied << rule::ID
    end

    Result.new(attributes: corrected, rule_ids: applied.freeze)
  end
end
