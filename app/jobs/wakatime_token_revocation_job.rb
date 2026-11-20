# The token is encrypted because GoodJob stores job arguments in plain text.
class WakatimeTokenRevocationJob < ApplicationJob
  queue_as :latency_5m

  retry_on HeartbeatImportDumpClient::TransientError, HTTP::Error,
    wait: :polynomially_longer, attempts: 10 do |_job, error|
      Rails.error.report(error, handled: true, context: { message: "Gave up revoking a WakaTime token" })
    end

  def self.revoke_later(token)
    perform_later(ActiveRecord::Encryption.encryptor.encrypt(token)) if token.present?
  end

  def perform(encrypted_token)
    HeartbeatImportDumpClient.revoke_wakatime_token(ActiveRecord::Encryption.encryptor.decrypt(encrypted_token))
  end
end
