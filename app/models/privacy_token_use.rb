class PrivacyTokenUse < ApplicationRecord
  self.primary_key = :jti

  def self.consume!(jti)
    # This receipt deliberately lives outside the erasure/dry-run transaction.
    transaction(requires_new: true) do
      create!(jti: jti)
      where("used_at < ?", 1.day.ago).delete_all
    end
  rescue ActiveRecord::RecordNotUnique
    raise Privacy::Error.new("replayed", 409)
  end
end
