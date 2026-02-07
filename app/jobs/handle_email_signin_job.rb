class HandleEmailSigninJob < ApplicationJob
  queue_as :latency_10s

  def perform(email, continue_param = nil)
    email_address = ActiveRecord::Base.transaction do
      EmailAddress.find_by(email: email) || begin
        user = User.create!
        user.email_addresses.create!(email: email, source: :signing_in)
      end
    end

    token = email_address.user.create_email_signin_token(continue_param: continue_param).token
    LoopsMailer.sign_in_email(email_address.email, token).deliver_now
    token
  end
end
