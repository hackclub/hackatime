class LoopsMailerPreview < ActionMailer::Preview
  def sign_in_email
    LoopsMailer.sign_in_email("user@example.com", "preview-token-abc123")
  end
end
