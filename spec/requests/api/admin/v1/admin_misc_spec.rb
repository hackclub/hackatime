require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::AdminMisc', type: :request, openapi_spec: 'admin/swagger.yaml' do
  path '/api/admin/v1/users/{id}/visualization/quantized' do
    get('Get quantized coding visualization for a user') do
      tags 'Admin'
      description 'Returns a per-day, quantized set of heartbeat points (for the given month) plus per-day total coding seconds. Used to render a compact activity visualization.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :id, in: :path, type: :string, required: true, description: 'User ID'
      parameter name: :year, in: :query, type: :integer, required: true, description: 'Year (e.g. 2024)'
      parameter name: :month, in: :query, type: :integer, required: true, description: 'Month (1-12)'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            days: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  date_timestamp_s: { type: :integer, example: 1704067200, description: 'Start-of-day epoch (seconds, UTC)' },
                  total_seconds: { type: :number, example: 7200.0, description: 'Total coding seconds for the day' },
                  points: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        time: { type: :number, example: 1704110400.0 },
                        lineno: { type: :integer, nullable: true, example: 42 },
                        cursorpos: { type: :integer, nullable: true, example: 12 }
                      }
                    }
                  }
                }
              }
            }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:viz_user) do
          u = User.create!(username: 'viz_user')
          EmailAddress.create!(user: u, email: 'viz@example.com')
          u
        end
        let(:id) { viz_user.id }
        let(:year) { 2024 }
        let(:month) { 1 }
        run_test!
      end

      response(422, 'invalid parameters — Returned ("invalid parameters") when year or month is missing or month is outside 1-12.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:viz_user) do
          u = User.create!(username: 'viz_user_invalid')
          EmailAddress.create!(user: u, email: 'viz-invalid@example.com')
          u
        end
        let(:id) { viz_user.id }
        let(:year) { 2024 }
        let(:month) { 13 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:id) { '0' }
        let(:year) { 2024 }
        let(:month) { 1 }
        run_test!
      end
    end
  end

  path '/api/admin/v1/alts/candidates' do
    get('List potential alt-account candidates') do
      tags 'Admin'
      description 'Returns pairs of users that have shared the same machine + IP address within the lookback window. Capped at 5000 candidate pairs.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :lookback_days, in: :query, type: :integer, required: false,
                description: 'Number of days to look back (default: 30, clamped to 1-365)'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            candidates: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user_a_id: { type: :integer, example: 42 },
                  user_b_id: { type: :integer, example: 43 },
                  machine: { type: :string, example: 'Orpheus-MacBook-Pro' },
                  ip_address: { type: :string, example: '203.0.113.7' },
                  user_a_first_seen_on_combo: { type: :number, example: 1710340200.0 },
                  user_a_last_seen_on_combo: { type: :number, example: 1710946200.0 },
                  user_b_first_seen_on_combo: { type: :number, example: 1710512400.0 },
                  user_b_last_seen_on_combo: { type: :number, example: 1710859800.0 }
                }
              }
            }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:lookback_days) { 30 }
        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['candidates']).to be_an(Array)
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-admin-key" }
        let(:lookback_days) { 30 }
        run_test!
      end
    end
  end

  path '/api/admin/v1/alts/shared_machines' do
    get('List machines used by multiple users (alts alias)') do
      tags 'Admin'
      description 'Alias path for the shared-machines report. Routes to the same action as GET /api/admin/v1/heartbeats/shared_machines and returns identical data.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :lookback_days, in: :query, type: :integer, required: false,
                description: 'Number of days to look back (default: 30, max: 365)'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Max results (default: 1000, max: 10000)'

      response(200, 'returns machines shared by multiple users') do
        schema type: :object,
          properties: {
            machines: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  machine:           { type: :string, example: 'Orpheus-MacBook-Pro' },
                  machine_frequency: { type: :integer, example: 2 },
                  user_ids:          { type: :string, example: '{42,43}', description: 'Postgres array literal of user IDs, e.g. "{12,34}"' }
                }
              }
            }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_a) do
          u = User.create!(username: 'alts_sm_a')
          EmailAddress.create!(user: u, email: 'alts_sm_a@example.com')
          u
        end
        let(:user_b) do
          u = User.create!(username: 'alts_sm_b')
          EmailAddress.create!(user: u, email: 'alts_sm_b@example.com')
          u
        end
        let(:lookback_days) { 30 }
        let(:limit) { nil }

        before do
          [ user_a, user_b ].each do |u|
            Heartbeat.create!(
              user: u,
              time: Time.current.to_i,
              project: 'demo',
              language: 'Ruby',
              editor: 'Zed',
              source_type: :direct_entry,
              branch: 'main',
              category: 'coding',
              is_write: true,
              user_agent: 'wakatime/1.0',
              operating_system: 'linux',
              machine: 'alts-shared-machine'
            )
          end
        end

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['machines']).to be_an(Array)
          entry = body['machines'].find { |m| m['machine'] == 'alts-shared-machine' }
          expect(entry).not_to be_nil
          expect(entry['user_ids']).to include(user_a.id.to_s, user_b.id.to_s)
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-admin-key" }
        let(:lookback_days) { 30 }
        let(:limit) { nil }
        run_test!
      end
    end
  end

  path '/api/admin/v1/users/active' do
    get('List recently active user IDs') do
      tags 'Admin'
      description 'Returns IDs of users with heartbeats since the given timestamp. The since value is floored to at most 90 days ago, and results are capped at 50,000 IDs.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :since, in: :query, type: :integer, required: false,
                description: 'Unix timestamp (seconds). Values older than 90 days ago are floored to 90 days ago. Negative values return 422.'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            user_ids: { type: :array, items: { type: :integer, example: 42 } }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:since) { 7.days.ago.to_i }
        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['user_ids']).to be_an(Array)
        end
      end

      response(422, 'invalid since parameter — Returned ("invalid since parameter") when since is negative.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:since) { -1 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/admin/v1/audit_logs/counts' do
    post('Count trust-level audit logs for users') do
      tags 'Admin'
      description 'Returns the number of trust-level audit log entries for each requested user ID. Users with no audit logs are included with a count of 0. Up to 1000 user IDs are honored.'
      security [ AdminToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        required: %w[user_ids],
        properties: {
          user_ids: {
            type: :array,
            items: { type: :integer, example: 42 },
            description: 'Array of user IDs (up to 1000). Required; a blank or non-array value returns 422.'
          }
        }
      }

      response(200, 'successful') do
        schema type: :object,
          properties: {
            counts: {
              type: :object,
              additionalProperties: { type: :integer, example: 3 },
              example: { '42' => 3, '43' => 0 },
              description: 'Map of user ID (as string) to audit log count.'
            }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:counts_user) do
          u = User.create!(username: 'audit_counts_user')
          EmailAddress.create!(user: u, email: 'audit-counts@example.com')
          u
        end
        let(:payload) { { user_ids: [ counts_user.id ] } }
        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['counts']).to be_a(Hash)
          expect(body['counts'][counts_user.id.to_s]).to eq(0)
        end
      end

      response(422, 'invalid user_ids — Returned ("user_ids array required") when user_ids is blank or not an array, or ("no valid user_ids provided") when the array is empty.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { user_ids: [] } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
