require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::Poisons', type: :request, openapi_spec: 'admin/swagger.yaml' do
  error_schema = {
    type: :object,
    properties: { error: { type: :string, example: 'User not found' } }
  }

  date_error_schema = {
    type: :object,
    properties: { error: { type: :string, example: 'date cannot be in the future' } }
  }

  poison_state_schema = {
    type: :object,
    properties: {
      user_id: { type: :integer, example: 42 },
      poisoned: { type: :boolean, example: true },
      poisoned_until: { type: :string, format: 'date-time', nullable: true, example: '2026-06-16T00:00:00Z' },
      poisoned_at: { type: :string, format: 'date-time', nullable: true, example: '2026-06-15T18:04:00Z' },
      poison_reason: { type: :string, nullable: true, example: 'Fraud!' },
      hidden_heartbeats: { type: :integer, example: 1284 }
    }
  }

  path '/api/admin/v1/poison/{hackatime_id}' do
    parameter name: :hackatime_id, in: :path, type: :string,
      description: 'Hackatime user identifier: numeric ID, Slack UID, HCA ID or username'

    get('Get Poison State') do
      tags 'Admin Resources'
      description "Report the current heartbeat poisoning state. Requires an admin, superadmin or ultraadmin API key. This endpoint was previously `/api/admin/v1/ban/{hackatime_id}`, which still works but is deprecated.\n"
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { create(:user, username: 'rswag_poison_show', timezone: 'UTC') }
        let(:hackatime_id) { target.id.to_s }

        before { target.apply_poison!((Date.current - 30).to_s, reason: 'Fraud!') }

        schema(**poison_state_schema)
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

    post('Poison Heartbeats') do
      tags 'Admin Resources'
      description <<~DESC
        Poison heartbeats. Requires an admin, superadmin or ultraadmin API key.
      DESC
      security [ AdminToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        description: 'Supply the cutoff as `date` or its alias `end_date`. Exactly one is required.',
        properties: {
          date: {
            type: :string,
            example: '2026-06-15',
            description: 'Inclusive last day to poison. A date (`YYYY-MM-DD`) covers ' \
                         "the whole day in the user's timezone; an ISO 8601 timestamp is " \
                         'treated as an absolute instant. Must not be in the future.'
          },
          end_date: { type: :string, example: '2026-06-15', description: 'Alias for `date`' },
          reason: { type: :string, nullable: true, example: 'Fraud!' }
        },
        anyOf: [
          { required: [ 'date' ] },
          { required: [ 'end_date' ] }
        ]
      }

      response(201, 'created') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { create(:user, username: 'rswag_poison_create', timezone: 'UTC') }
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
        let(:target) { create(:user, username: 'rswag_poison_future', timezone: 'UTC') }
        let(:hackatime_id) { target.id.to_s }
        let(:payload) { { date: (Date.current + 1).to_s } }
        schema(**date_error_schema)
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:hackatime_id) { 'no-such-user' }
        let(:payload) { { date: (Date.current - 30).to_s } }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized - Returned when the key is missing, invalid, or below admin level.') do
        let(:Authorization) { "Bearer viewer-admin-api-key-rswag-poison" }
        let(:hackatime_id) { '1' }
        let(:payload) { { date: (Date.current - 30).to_s } }

        before do
          u = create(:user, :viewer, username: 'rswag_poison_viewer', timezone: 'UTC')
          create(:admin_api_key, user: u, name: 'Viewer Poison Key', token: 'viewer-admin-api-key-rswag-poison')
        end

        run_test!
      end
    end

    delete('Un-Poison Heartbeats') do
      tags 'Admin Resources'
      description <<~DESC
        Lift the poison. Requires an admin, superadmin or ultraadmin API key.
      DESC
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { create(:user, username: 'rswag_poison_delete', timezone: 'UTC') }
        let(:hackatime_id) { target.id.to_s }

        before { target.apply_poison!((Date.current - 30).to_s, reason: 'Fraud!') }

        schema type: :object,
          properties: {
            success: { type: :boolean, example: true },
            user_id: { type: :integer, example: 42 },
            poisoned_until: { type: :string, nullable: true, example: nil },
            already_unpoisoned: { type: :boolean, example: false, description: 'Present when the user was not poisoned' },
            already_unbanned: { type: :boolean, example: false, description: 'Deprecated alias of already_unpoisoned' }
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
