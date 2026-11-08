class RevokeExpiredAdminApiKeysJob < ApplicationJob
  queue_as :literally_whenever

  def perform
    AdminApiKey.expired.find_each(&:revoke!)
  end
end
