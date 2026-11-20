# Revokes a WakaTime OAuth token once Hackatime no longer needs it. The token
# is stored encrypted in the job arguments so a WakaTime outage can be retried
# after the import run has dropped its copy.
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
