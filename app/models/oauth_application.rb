class OauthApplication < Doorkeeper::Application
  belongs_to :owner, polymorphic: true, optional: true

  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }

  attr_accessor :admin_bypass

  validate :locked_name, on: :update

  private

  def locked_name
    return if admin_bypass
    return unless verified? && name_changed?

    errors.add(:name, "cannot be changed for verified apps")
  end
end
