class AdminApiKeyMailerPreview < ActionMailer::Preview
  def expiry_notice
    user = User.first || User.new(username: "preview_user", timezone: "UTC")
    keys = [
      AdminApiKey.new(name: "Fraud check tool", token_preview: "hka_3f8e12ab5", expires_at: 48.days.from_now),
      AdminApiKey.new(name: "Billy's script", token_preview: "hka_9c01d7e42", expires_at: 48.days.from_now)
    ]

    AdminApiKeyMailer.expiry_notice(user, keys, recipient_email: "admin@example.com")
  end
end
