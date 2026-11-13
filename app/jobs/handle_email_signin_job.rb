class HandleEmailSigninJob < ApplicationJob
  queue_as :latency_critical

  # Accounts are only created through Hack Club Auth, so an unknown email gets
  # nothing, and so does an email kept from a deleted account. Jobs queued
  # before that change still pass an IP address.
  def perform(email, continue_param = nil, _ip_address = nil)
    email_address = EmailAddress.not_source_preserved_for_deletion.find_by(email: email)
    return if email_address.nil?

    token = email_address.user.create_email_signin_token(continue_param: continue_param).token
    LoopsMailer.sign_in_email(email_address.email, token).deliver_now
    token
  end
end
