require 'swagger_helper'

RSpec.describe 'Api::Internal', type: :request do
  path '/api/internal/revoke' do
    post('Revoke access') do
      tags 'Internal'
      description 'Internal endpoint to revoke access tokens. Use with caution. Requires HKA_REVOCATION_KEY environment variable authentication. This is used for Revoker to allow security researchers to revoke compromised tokens.'
      security [ InternalToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          token: { type: :string },
          submitter: { type: :string },
          comment: { type: :string }
        },
        required: [ 'token' ]
      }

      response(201, 'created') do
        let(:Authorization) { "Bearer test_revocation_key" }
        let(:user) { User.create!(timezone: "UTC") }
        let!(:email_address) { user.email_addresses.create!(email: "internal@example.com", source: :signing_in) }
        let!(:api_key) { user.api_keys.create!(name: "Desktop") }
        let(:payload) { { token: api_key.token } }

        before do
          ENV["HKA_REVOCATION_KEY"] = "test_revocation_key"
        end

        after do
          ENV.delete("HKA_REVOCATION_KEY")
        end

        schema type: :object,
          properties: {
            success: { type: :boolean },
            status: { type: :string },
            token_type: { type: :string },
            owner_email: { type: :string, nullable: true },
            key_name: { type: :string, nullable: true }
          }
        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["success"]).to eq(true)
          expect(body["status"]).to eq("complete")
          expect(body["token_type"]).to eq("Hackatime API Key")
          expect(body["owner_email"]).to eq(email_address.email)
          expect(body["key_name"]).to eq(api_key.name)
        end
      end

      response(422, 'unprocessable entity') do
        let(:Authorization) { "Bearer test_revocation_key" }
        let(:payload) { { token: SecureRandom.uuid_v4 } }

        before do
          ENV["HKA_REVOCATION_KEY"] = "test_revocation_key"
        end

        after do
          ENV.delete("HKA_REVOCATION_KEY")
        end

        schema type: :object,
          properties: {
            success: { type: :boolean },
            error: { type: :string }
          },
          required: [ 'success', 'error' ]
        run_test!
      end
    end
  end
end
