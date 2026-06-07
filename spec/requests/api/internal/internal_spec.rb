require 'swagger_helper'

RSpec.describe 'Api::Internal', type: :request, openapi_spec: 'admin/swagger.yaml' do
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
          token: { type: :string, example: '3f8e9c2a-7b14-4d6e-9a2f-1c8b5d3e7f01', description: 'The API key token to revoke (a regular UUID-format key or an admin "hka_" key).' }
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
            success: { type: :boolean, example: true },
            status: { type: :string, example: 'complete' },
            token_type: { type: :string, example: 'Desktop', description: 'The name of the revoked key (e.g. the regular API key\'s name such as "Desktop" or the default "Hackatime key"; for admin keys, the admin key\'s name). This is the key name, not a type descriptor.' },
            owner_email: { type: :string, nullable: true, example: 'orpheus@hackclub.com' },
            key_name: { type: :string, nullable: true, example: 'Revoker admin key', description: 'Present only when revoking an admin ("hka_") key; the admin key\'s name.' }
          }
        run_test! do |response|
          body = JSON.parse(response.body)

          expect(body["success"]).to eq(true)
          expect(body["status"]).to eq("complete")
          expect(body["token_type"]).to eq("Desktop")
          expect(body["owner_email"]).to eq(email_address.email)
          expect(body).not_to have_key("key_name")
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
            success: { type: :boolean, example: false },
            error: { type: :string, example: 'Token is invalid or already revoked' }
          },
          required: [ 'success', 'error' ]
        run_test!
      end

      response(302, 'redirect on failed authentication — When the provided token does not match HKA_REVOCATION_KEY (or is missing), the controller does not return 401; it issues a 302 redirect to an external URL.') do
        let(:Authorization) { "Bearer wrong_revocation_key" }
        let(:payload) { { token: SecureRandom.uuid_v4 } }

        before do
          ENV["HKA_REVOCATION_KEY"] = "test_revocation_key"
        end

        after do
          ENV.delete("HKA_REVOCATION_KEY")
        end

        run_test!
      end
    end
  end
end
