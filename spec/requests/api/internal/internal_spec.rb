require 'swagger_helper'

RSpec.describe 'Api::Internal', type: :request do
  path '/api/internal/revoke' do
    post('Revoke access') do
      tags 'Internal'
      description 'Internal endpoint to revoke access tokens. Use with caution. Requires HKA_REVOCATION_KEY environment variable authentication.'
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
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("HKA_REVOCATION_KEY").and_return("test_revocation_key")
          allow(ActiveSupport::SecurityUtils).to receive(:secure_compare).with("test_revocation_key", "test_revocation_key").and_return(true)
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
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("HKA_REVOCATION_KEY").and_return("test_revocation_key")
          allow(ActiveSupport::SecurityUtils).to receive(:secure_compare).with("test_revocation_key", "test_revocation_key").and_return(true)
        end

        run_test!
      end
    end
  end

  path '/api/internal/can_i_have_a_magic_link_for/{id}' do
    post('Create magic link') do
      tags 'Internal'
      description 'Internal endpoint to generate magic login links for users via Slack UID and Email.'
      security [ InternalToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :string, description: 'Slack UID'
      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string, format: :email },
          continue_param: { type: :string },
          return_data: { type: :object }
        },
        required: [ 'email' ]
      }

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:id) { 'U123456' }
        let(:payload) { { email: 'test@example.com' } }

        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("INTERNAL_API_KEYS").and_return("dev-api-key-12345")
        end

        schema type: :object,
          properties: {
            magic_link: { type: :string },
            existing: { type: :boolean }
          }
        run_test!
      end

      response(400, 'bad request') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:id) { 'U123456' }
        let(:payload) { { email: '' } }

        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("INTERNAL_API_KEYS").and_return("dev-api-key-12345")
        end

        run_test!
      end
    end
  end
end
