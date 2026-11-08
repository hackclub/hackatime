class RevokeExpiredAdminApiKeysJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    AdminApiKey.where(revoked_at: nil, expires_at: ..Time.current).find_each(&:revoke!)
  end
end
