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
          token: { type: :string }
        },
        required: [ 'token' ]
      }

      response(200, 'successful') do
        let(:Authorization) { "Bearer test_revocation_key" }
        let(:payload) { { token: 'some_token' } }

        before do
          ENV["HKA_REVOCATION_KEY"] = "test_revocation_key"
        end

        after do
          ENV.delete("HKA_REVOCATION_KEY")
        end

        schema type: :object,
          properties: {
            success: { type: :boolean },
            owner_email: { type: :string, nullable: true },
            key_name: { type: :string, nullable: true }
          }
        run_test!
      end

      response(400, 'bad request') do
        let(:Authorization) { "Bearer test_revocation_key" }
        let(:payload) { { token: nil } }

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
