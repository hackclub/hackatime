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
        before { ENV['STATS_API_KEY'] = 'dev-admin-api-key-12345' }
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { token: 'valid_slack_token' } }
        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("STATS_API_KEY").and_return('dev-admin-api-key-12345')
          allow(HTTP).to receive(:auth).and_return(double(get: double(body: { ok: true, user_id: 'U123456' }.to_json)))
          allow_any_instance_of(User).to receive(:raw_slack_user_info).and_return({
            "profile" => { "email" => "test@example.com" },
            "tz" => "UTC"
          })
          allow_any_instance_of(User).to receive(:update_from_slack)
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
        before do
          allow(ENV).to receive(:[]).and_call_original
          allow(ENV).to receive(:[]).with("STATS_API_KEY").and_return('dev-admin-api-key-12345')
        end
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { token: nil } }
        run_test! do |response|
          expect(response.status).to eq(400)
        end
      end
    end
  end

  path '/api/v1/ysws_programs' do
    get('List YSWS Programs') do
      tags 'YSWS Programs'
      description 'List available YSWS (Your Ship We Ship) programs.'
      produces 'application/json'

      response(200, 'successful') do
        schema type: :array,
          items: { type: :string, example: 'onboard' }
        run_test!
      end
    end
  end

  path '/api/v1/ysws_programs/claim' do
    post('Claim YSWS Program') do
      tags 'YSWS Programs'
      description 'Claim a YSWS program reward.'
      consumes 'application/json'
      produces 'application/json'
      security [ Bearer: [], ApiKeyAuth: [] ]

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          program_id: { type: :integer, description: 'YSWS Program ID' },
          user_id: { type: :string, description: 'User ID or Slack UID' },
          start_time: { type: :string, format: :date_time, description: 'Start time of the claim period' },
          end_time: { type: :string, format: :date_time, description: 'End time of the claim period' },
          project: { type: :string, description: 'Project name (optional)', nullable: true }
        },
        required: [ 'program_id', 'user_id', 'start_time', 'end_time' ]
      }

      response(200, 'successful') do
        before { ENV['STATS_API_KEY'] = 'dev-admin-api-key-12345' }
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:api_key) { "dev-admin-api-key-12345" }
        let(:user) {
          User.find_by(username: 'testuser') || begin
            u = User.create!(username: 'testuser', slack_uid: 'U123456')
            u.email_addresses.create!(email: 'test@example.com')
            u
          end
        }
        let(:payload) { {
          program_id: 1,
          user_id: user.id.to_s,
          start_time: (Time.now - 1.hour).iso8601,
          end_time: (Time.now + 1.hour).iso8601,
          project: 'test'
        } }
        schema type: :object,
          properties: {
            message: { type: :string, example: 'Successfully claimed 100 heartbeats' },
            claimed_count: { type: :integer, example: 100 }
          }
        run_test!
      end

      response(409, 'conflict') do
        before { ENV['STATS_API_KEY'] = 'dev-admin-api-key-12345' }
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:api_key) { "dev-admin-api-key-12345" }
        let(:user) {
          User.find_by(username: 'testuser') || begin
            u = User.create!(username: 'testuser', slack_uid: 'U123456')
            u.email_addresses.create!(email: 'test@example.com')
            u
          end
        }
        let(:time_base) { Time.current }
        let(:payload) { {
          program_id: 1,
          user_id: user.id.to_s,
          start_time: (time_base - 1.hour).iso8601,
          end_time: (time_base + 1.hour).iso8601,
          project: 'test'
        } }

        before do
          Heartbeat.create!(
            user: user,
            time: time_base,
            ysws_program: :high_seas,
            project: 'test',
            language: 'Ruby',
            editor: 'VS Code',
            source_type: :direct_entry,
            branch: 'main',
            category: 'coding',
            is_write: true,
            user_agent: 'test',
            operating_system: 'linux',
            machine: 'test-machine'
          )
        end

        schema type: :object,
          properties: {
            error: { type: :string },
            conflicts: { type: :array, items: { type: :array } }
          }
        run_test!
      end
    end
  end
end
