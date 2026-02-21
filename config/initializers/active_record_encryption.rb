if Rails.env.test?
  ENV["ENCRYPTION_PRIMARY_KEY"] ||= "test_primary_key_for_active_record_encryption_123"
  ENV["ENCRYPTION_DETERMINISTIC_KEY"] ||= "test_deterministic_key_for_active_record_encrypt_456"
  ENV["ENCRYPTION_KEY_DERIVATION_SALT"] ||= "test_key_derivation_salt_789"
end

Rails.application.config.active_record.encryption.primary_key = ENV["ENCRYPTION_PRIMARY_KEY"]
Rails.application.config.active_record.encryption.deterministic_key = ENV["ENCRYPTION_DETERMINISTIC_KEY"]
Rails.application.config.active_record.encryption.key_derivation_salt = ENV["ENCRYPTION_KEY_DERIVATION_SALT"]
