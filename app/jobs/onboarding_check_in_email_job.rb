class OnboardingCheckInEmailJob < ApplicationJob
  queue_as :literally_whenever

  def perform(user_id)
    user = User.find_by(id: user_id)
    return if user.nil?
    return if user.pending_deletion?

    recipient_email = user.email_addresses.order(:id).pick(:email)
    nil if recipient_email.blank?

    # OnboardingMailer.check_in(user, recipient_email: recipient_email).deliver_now
  end
end
