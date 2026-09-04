require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::Bans', type: :request, openapi_spec: 'admin/swagger.yaml' do
  error_schema = {
    type: :object,
    properties: { error: { type: :string, example: 'User not found' } }
  }

  ban_state_schema = {
    type: :object,
    properties: {
      user_id: { type: :integer, example: 42 },
      poisoned: { type: :boolean, example: true },
      poisoned_until: { type: :string, format: 'date-time', nullable: true, example: '2026-06-16T00:00:00Z' },
      poisoned_at: { type: :string, format: 'date-time', nullable: true, example: '2026-06-15T18:04:00Z' },
      poison_reason: { type: :string, nullable: true, example: 'Telescreen: fabricated heartbeats' },
      hidden_heartbeats: { type: :integer, example: 1284 }
    }
  }

  path '/api/admin/v1/ban/{hackatime_id}' do
    parameter name: :hackatime_id, in: :path, type: :string,
      description: 'Hackatime user identifier: numeric ID, Slack UID, HCA ID or username'

    get('Get Ban State') do
      tags 'Admin Resources'
      description <<~DESC
        Report the current heartbeat poisoning state, including the cutoff, when the
        ban was applied and the recorded reason. Requires a superadmin API key.
      DESC
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { create(:user, username: 'rswag_ban_show', timezone: 'UTC') }
        let(:hackatime_id) { target.id.to_s }

        before { target.apply_poison!((Date.current - 30).to_s, reason: 'Fraud!') }

        schema(**ban_state_schema)
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:hackatime_id) { 'no-such-user' }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:hackatime_id) { '1' }
        run_test!
      end
    end

    post('Poison Heartbeats (Ban)') do
      tags 'Admin Resources'
      description <<~DESC
        Poison Hearbeats!
      DESC
      security [ AdminToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          date: { type: :string, format: 'date', example: '2026-06-15', description: 'Inclusive last day to poison' },
          end_date: { type: :string, format: 'date', example: '2026-06-15', description: 'Alias for `date`' },
          reason: { type: :string, nullable: true, example: 'Fraud!' }
        },
        required: [ 'date' ]
      }

      response(201, 'created') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { create(:user, username: 'rswag_ban_create', timezone: 'UTC') }
        let(:hackatime_id) { target.id.to_s }
        let(:payload) { { date: (Date.current - 30).to_s, reason: 'Fraud!' } }

        schema type: :object,
          properties: {
            success: { type: :boolean, example: true },
            user_id: { type: :integer, example: 42 },
            poisoned_until: { type: :string, format: 'date-time', example: '2026-06-16T00:00:00Z' },
            poisoned_at: { type: :string, format: 'date-time', example: '2026-06-15T18:04:00Z' },
            poison_reason: { type: :string, nullable: true, example: 'Fraud!' },
            hidden_heartbeats: { type: :integer, example: 1284 }
          }

        run_test!
      end

      response(422, 'invalid date - Returned when the date is missing, unparseable, or in the future.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { create(:user, username: 'rswag_ban_future', timezone: 'UTC') }
        let(:hackatime_id) { target.id.to_s }
        let(:payload) { { date: (Date.current + 1).to_s } }
        schema(**error_schema)
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:hackatime_id) { 'no-such-user' }
        let(:payload) { { date: (Date.current - 30).to_s } }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized - Returned when the key is missing, invalid, or not superadmin level.') do
        let(:Authorization) { "Bearer viewer-admin-api-key-rswag-ban" }
        let(:hackatime_id) { '1' }
        let(:payload) { { date: (Date.current - 30).to_s } }

        before do
          u = create(:user, :viewer, username: 'rswag_ban_viewer', timezone: 'UTC')
          create(:admin_api_key, user: u, name: 'Viewer Ban Key', token: 'viewer-admin-api-key-rswag-ban')
        end

        run_test!
      end
    end

    delete('Remove Poison (Unban)') do
      tags 'Admin Resources'
      description <<~DESC
        Lift the poison. Requires a superadmin API key.
      DESC
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { create(:user, username: 'rswag_ban_delete', timezone: 'UTC') }
        let(:hackatime_id) { target.id.to_s }

        before { target.apply_poison!((Date.current - 30).to_s, reason: 'Fraud!') }

        schema type: :object,
          properties: {
            success: { type: :boolean, example: true },
            user_id: { type: :integer, example: 42 },
            poisoned_until: { type: :string, nullable: true, example: nil },
            already_unbanned: { type: :boolean, example: false, description: 'Present when the user was not banned' }
          }

        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:hackatime_id) { 'no-such-user' }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:hackatime_id) { '1' }
        run_test!
      end
    end
  end
end
