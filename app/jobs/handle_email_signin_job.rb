class HandleEmailSigninJob < ApplicationJob
  queue_as :latency_critical

  def perform(email, continue_param = nil, ip_address = nil)
    email_address = ActiveRecord::Base.transaction do
      EmailAddress.find_by(email: email) || begin
        user = User.create!(country_code: User.country_code_from_ip(ip_address))
        user.email_addresses.create!(email: email, source: :signing_in)
      end
    end

    token = email_address.user.create_email_signin_token(continue_param: continue_param).token
    LoopsMailer.sign_in_email(email_address.email, token).deliver_now
    token
  end
end
