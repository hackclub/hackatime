require 'swagger_helper'

RSpec.describe 'Api::V1::External', type: :request do
  path '/api/v1/external/slack/oauth' do
    post('Create user from Slack OAuth') do
      tags 'External Integrations'
      description <<~DESC
        Callback endpoint for Slack OAuth to create or update a user.

        Requires the legacy stats API key in the `Authorization` header
        (`Bearer <STATS_API_KEY>`); the `?api_key=` query param is NOT accepted.

        If a user with the resolved Slack UID already exists the endpoint returns
        200 with the existing user. If the user is new it is created from the
        Slack profile and the endpoint returns 201.
      DESC
      consumes 'application/json'
      produces 'application/json'
      security [ Bearer: [] ]

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          token: { type: :string, description: 'Slack OAuth Token', example: 'xoxp-1234567890-0987654321-abcdef' }
        },
        required: [ 'token' ]
      }

      response(200, 'existing user', document: false) do
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
            user_id: { type: :integer, example: 42 },
            username: { type: :string, example: 'orpheus' },
            email: { type: :string, nullable: true, example: 'orpheus@hackclub.com' }
          }
        run_test! do |response|
          expect(response.status).to eq(200)
        end
      end

      response(201, 'new user created', document: false) do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { token: 'valid_slack_token' } }
        let(:slack_uid) { "U_NEW_#{SecureRandom.hex(4)}" }
        before do
          ENV['STATS_API_KEY'] = 'dev-admin-api-key-12345'

          stub_request(:get, "https://slack.com/api/auth.test")
            .to_return(
              status: 200,
              body: { ok: true, user_id: slack_uid }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )

          stub_request(:get, %r{https://slack\.com/api/users\.info})
            .to_return(
              status: 200,
              body: {
                ok: true,
                user: {
                  name: 'newperson',
                  tz: 'America/New_York',
                  profile: { email: 'newperson@example.com', display_name_normalized: 'newperson' }
                }
              }.to_json,
              headers: { 'Content-Type' => 'application/json' }
            )
        end

        after do
          ENV['STATS_API_KEY'] = 'dev-api-key-12345'
        end

        schema type: :object,
          properties: {
            user_id: { type: :integer, example: 42 },
            username: { type: :string, example: 'orpheus' },
            email: { type: :string, nullable: true, example: 'orpheus@hackclub.com' }
          }
        run_test! do |response|
          expect(response.status).to eq(201)
        end
      end

      response(400, 'bad request — Returned with { "error": <message> } for: "Token is required" (token blank), "User ID not found" (Slack auth_data has no user_id), or "Email not found" (Slack profile has no email).', document: false) do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { token: nil } }

        before do
          ENV['STATS_API_KEY'] = 'dev-admin-api-key-12345'
        end

        after do
          ENV['STATS_API_KEY'] = 'dev-api-key-12345'
        end

        schema '$ref' => '#/components/schemas/Error'
        run_test! do |response|
          expect(response.status).to eq(400)
          expect(JSON.parse(response.body)['error']).to eq('Token is required')
        end
      end

      response(401, 'unauthorized — Returned with { "error": "Invalid API token" } when the Authorization header does not match STATS_API_KEY, or { "error": "Invalid Slack token" } when Slack auth.test returns ok:false.', document: false) do
        let(:Authorization) { "Bearer wrong-key" }
        let(:payload) { { token: 'whatever' } }

        before do
          ENV['STATS_API_KEY'] = 'dev-admin-api-key-12345'
        end

        after do
          ENV['STATS_API_KEY'] = 'dev-api-key-12345'
        end

        schema '$ref' => '#/components/schemas/Error'
        run_test! do |response|
          expect(response.status).to eq(401)
          expect(JSON.parse(response.body)['error']).to eq('Invalid API token')
        end
      end

      response(500, 'internal server error — Returned with { "error": "Internal server error" } when an unexpected exception is raised (e.g. the Slack auth.test response is not valid JSON).', document: false) do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { token: 'valid_slack_token' } }

        before do
          ENV['STATS_API_KEY'] = 'dev-admin-api-key-12345'
          stub_request(:get, "https://slack.com/api/auth.test")
            .to_return(status: 200, body: 'not json', headers: { 'Content-Type' => 'application/json' })
        end

        after do
          ENV['STATS_API_KEY'] = 'dev-api-key-12345'
        end

        schema '$ref' => '#/components/schemas/Error'
        run_test! do |response|
          expect(response.status).to eq(500)
          expect(JSON.parse(response.body)['error']).to eq('Internal server error')
        end
      end
    end
  end
end
