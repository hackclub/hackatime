require 'swagger_helper'

RSpec.describe 'Api::V1::External', type: :request do
  path '/api/v1/external/slack/oauth' do
    post('Create user from Slack OAuth') do
      tags 'External Integrations'
      description 'Callback endpoint for Slack OAuth to create or update a user.'
      consumes 'application/json'
      produces 'application/json'
      security [ Bearer: [] ]

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          token: { type: :string, description: 'Slack OAuth Token' }
        },
        required: [ 'token' ]
      }

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { token: 'valid_slack_token' } }
        before do
          ENV['STATS_API_KEY'] = 'dev-admin-api-key-12345'

          stub_request(:get, "https://slack.com/api/auth.test")
            .to_return(
              status: 200,
              body: { ok: true, user_id: 'U_SLACK_OAUTH' }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )

          user = User.find_or_create_by!(slack_uid: 'U_SLACK_OAUTH') do |u|
            u.username = 'slack_oauth_user'
            u.timezone = 'UTC'
          end
          user.email_addresses.find_or_create_by!(email: 'slacktest@example.com') do |e|
            e.source = :slack
          end
        end

        after do
          ENV['STATS_API_KEY'] = 'dev-api-key-12345'
        end

        schema type: :object,
          properties: {
            user_id: { type: :integer },
            username: { type: :string },
            email: { type: :string, nullable: true }
          }
        run_test!
      end

      response(400, 'bad request') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { token: nil } }

        before do
          ENV['STATS_API_KEY'] = 'dev-admin-api-key-12345'
        end

        after do
          ENV['STATS_API_KEY'] = 'dev-api-key-12345'
        end

        run_test! do |response|
          expect(response.status).to eq(400)
        end
      end
    end
  end

end
