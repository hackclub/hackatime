require 'swagger_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  path '/api/v1/users/lookup_email/{email}' do
    get('Lookup user by email') do
      tags 'Users'
      description 'Find a user ID by their email address. Useful for integrations that need to map emails to Hackatime users. Requires an active Admin API Key supplied via the Authorization Bearer header.'
      security [ Bearer: [] ]
      produces 'application/json'

      parameter name: :email, in: :path, type: :string, description: 'Email address to lookup'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:email) { 'test@example.com' }
        schema type: :object,
          properties: {
            user_id: { type: :integer, example: 42 },
            email: { type: :string, example: 'orpheus@hackclub.com' }
          }
        run_test! do |response|
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body["email"]).to eq(email)
          expect(body["user_id"]).to be_present
        end
      end

      response(401, 'unauthorized — Returned when the Admin API Key is missing, revoked, or incorrect. (Auth is bypassed in the development environment.)') do
        let(:Authorization) { "Bearer wrong-token" }
        let(:email) { 'orpheus@hackclub.com' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(404, 'not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:email) { 'unknown@example.com' }
        schema type: :object,
          properties: {
            error: { type: :string, example: 'User not found' },
            email: { type: :string, example: 'unknown@example.com' }
          }
        run_test!
      end
    end
  end

  path '/api/v1/users/lookup_slack_uid/{slack_uid}' do
    get('Lookup user by Slack UID') do
      tags 'Users'
      description 'Find a user ID by their Slack User ID. Requires an active Admin API Key supplied via the Authorization Bearer header'
      security [ Bearer: [] ]
      produces 'application/json'

      parameter name: :slack_uid, in: :path, type: :string, description: 'Slack User ID (e.g. U123456)'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:slack_uid) { 'TEST123456' }
        schema type: :object,
          properties: {
            user_id: { type: :integer, example: 42 },
            slack_uid: { type: :string, example: 'U0266FRGP' }
          }
        run_test!
      end

      response(401, 'unauthorized — Returned when the Admin API Key is missing, revoked, or incorrect. (Auth is bypassed in the development environment.)') do
        let(:Authorization) { "Bearer wrong-token" }
        let(:slack_uid) { 'TEST123456' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(404, 'not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:slack_uid) { 'U000000' }
        schema type: :object,
          properties: {
            error: { type: :string, example: 'User not found' },
            slack_uid: { type: :string, example: 'U000000' }
          }
        run_test!
      end
    end
  end
end
