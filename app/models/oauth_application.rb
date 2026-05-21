class OauthApplication < Doorkeeper::Application
  belongs_to :owner, polymorphic: true, optional: true

  scope :verified, -> { where(verified: true) }
  scope :unverified, -> { where(verified: false) }

  validate :locked_name, on: :update

  # Update the application as an admin, allowing the otherwise-locked `name`
  # validation on verified apps to pass. Use this from admin controllers
  # instead of toggling a public `admin_bypass` attribute (which made the
  # bypass a hidden, accidentally-settable property of the record).
  def admin_update(attrs)
    with_admin_override { update(attrs) }
  end

  def admin_update!(attrs)
    with_admin_override { update!(attrs) }
  end

  private

  def with_admin_override
    previous = @admin_override
    @admin_override = true
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
