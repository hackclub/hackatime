class OauthApplication < Doorkeeper::Application
  belongs_to :owner, polymorphic: true, optional: true

  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }

  validate :locked_name, on: :update

  # Update as admin, bypassing the locked-name validation on verified apps.
  def admin_update(attrs) = with_admin_override { update(attrs) }
  def admin_update!(attrs) = with_admin_override { update!(attrs) }

  private

  def with_admin_override
    previous, @admin_override = @admin_override, true
    yield
  ensure
    @admin_override = previous
  end

  def locked_name
    return if @admin_override
    return unless verified? && name_changed?
    errors.add(:name, "cannot be changed for verified apps")
  end
end
