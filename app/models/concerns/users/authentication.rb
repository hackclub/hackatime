module Users
  module Authentication
    extend ActiveSupport::Concern

    def create_email_signin_token(continue_param: nil)
      sign_in_tokens.create!(auth_type: :email, continue_param: continue_param)
    end

    def rotate_api_keys!
      api_keys.transaction do
        api_keys.destroy_all
        api_keys.create!(name: "Hackatime key")
      end
    end

    def rotate_single_api_key!(api_key)
      raise ActiveRecord::RecordNotFound unless api_key.user_id == id

      api_key.update!(token: SecureRandom.uuid_v4)
      api_key
    end

    def find_valid_token(token)
      sign_in_tokens.valid.find_by(token: token)
    end
  end
end
