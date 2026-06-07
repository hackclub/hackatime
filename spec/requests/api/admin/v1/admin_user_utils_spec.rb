require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::UserUtils', type: :request, openapi_spec: 'admin/swagger.yaml' do
  path '/api/admin/v1/user/info_batch' do
    get('Get user info batch') do
      tags 'Admin Utils'
      description 'Get info for multiple users.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :ids, in: :query, type: :string, required: true, description: 'Comma-separated list of user IDs (e.g. "1,2,3"). Up to 2000 ids are honored.'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:u1) do
          u = User.create!(username: 'u1')
          EmailAddress.create!(user: u, email: 'u1@example.com')
          u
        end
        let(:u2) do
          u = User.create!(username: 'u2')
          EmailAddress.create!(user: u, email: 'u2@example.com')
          u
        end
        let(:ids) { "#{u1.id},#{u2.id}" }
        schema type: :object,
          properties: {
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, example: 42 },
                  username: { type: :string, example: 'orpheus' },
                  display_name: { type: :string, example: 'orpheus' },
                  slack_uid: { type: :string, nullable: true, example: 'U0266FRGP' },
                  slack_username: { type: :string, nullable: true, example: 'orpheus' },
                  github_username: { type: :string, nullable: true, example: 'orpheus' },
                  timezone: { type: :string, nullable: true, example: 'America/New_York' },
                  country_code: { type: :string, nullable: true, example: 'US' },
                  trust_level: { type: :string, example: 'blue' },
                  avatar_url: { type: :string, nullable: true, example: 'https://avatars.slack-edge.com/2024-03-20/orpheus_512.png' },
                  slack_avatar_url: { type: :string, nullable: true, example: 'https://avatars.slack-edge.com/2024-03-20/orpheus_512.png' },
                  github_avatar_url: { type: :string, nullable: true, example: 'https://avatars.githubusercontent.com/u/12345?v=4' }
                }
              }
            }
          }
        run_test! do |response|
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body["users"]).to be_an(Array)
          returned_ids = body["users"].map { |entry| entry["id"] }
          expect(returned_ids & [ u1.id, u2.id ]).not_to be_empty
        end
      end

      response(422, 'ids missing or no valid ids — Returned when the ids parameter is blank ("ids parameter required") or when none of the supplied ids parse to a valid integer ("no valid ids provided").') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:ids) { '' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/info' do
    get('Get user info') do
      tags 'Admin Utils'
      description 'Get detailed info for a single user.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'User ID. Either user_id or id may be supplied.'
      parameter name: :id, in: :query, type: :string, required: false, description: 'Alias for user_id. If both id and user_id are supplied, id takes precedence.'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'info_user')
          EmailAddress.create!(user: u, email: 'info@example.com')
          u
        end
        let(:user_id) { user.id }
        schema type: :object,
          properties: {
            user: {
              type: :object,
              properties: {
                id: { type: :integer, example: 42 },
                username: { type: :string, example: 'orpheus' },
                display_name: { type: :string, example: 'orpheus' },
                slack_uid: { type: :string, nullable: true, example: 'U0266FRGP' },
                slack_username: { type: :string, nullable: true, example: 'orpheus' },
                github_username: { type: :string, nullable: true, example: 'orpheus' },
                timezone: { type: :string, nullable: true, example: 'America/New_York' },
                country_code: { type: :string, nullable: true, example: 'US' },
                admin_level: { type: :string, example: 'default' },
                trust_level: { type: :string, example: 'blue' },
                suspected: { type: :boolean, example: false },
                banned: { type: :boolean, example: false },
                created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
                updated_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
                last_heartbeat_at: { type: :number, nullable: true, example: 1710946200.0 },
                email_addresses: { type: :array, items: { type: :string, example: 'orpheus@hackclub.com' } },
                api_keys_count: { type: :integer, example: 2 },
                stats: {
                  type: :object,
                  properties: {
                    total_heartbeats: { type: :integer, example: 15234 },
                    total_coding_time: { type: :number, example: 187200.0 },
                    languages_used: { type: :integer, example: 8 },
                    projects_worked_on: { type: :integer, example: 12 },
                    days_active: { type: :integer, example: 47 }
                  }
                }
              }
            }
          }
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { '0' }
        run_test!
      end

      response(422, 'missing id — Returned ("who?") when neither id nor user_id is supplied.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { '' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/heartbeats' do
    get('Get admin user heartbeats') do
      tags 'Admin Utils'
      description 'Get heartbeats for a user (Admin view).'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'User ID. Either user_id or id may be supplied.'
      parameter name: :id, in: :query, type: :string, required: false, description: 'Alias for user_id. If both id and user_id are supplied, id takes precedence.'
      parameter name: :start_date, in: :query, type: :string, description: 'Start date (YYYY-MM-DD or timestamp)'
      parameter name: :end_date, in: :query, type: :string, description: 'End date (YYYY-MM-DD or timestamp)'
      parameter name: :project, in: :query, type: :string, description: 'Project name'
      parameter name: :language, in: :query, type: :string, description: 'Language'
      parameter name: :entity, in: :query, type: :string, description: 'Entity (file path or app name)'
      parameter name: :editor, in: :query, type: :string, description: 'Editor'
      parameter name: :machine, in: :query, type: :string, description: 'Machine'
      parameter name: :limit, in: :query, type: :integer, description: 'Limit'
      parameter name: :offset, in: :query, type: :integer, description: 'Offset'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            user_id: { type: :integer, example: 42 },
            heartbeats: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, example: 987654 },
                  time: { type: :number, example: 1710946200.0 },
                  lineno: { type: :integer, example: 42, description: 'Coalesced to 0 when null' },
                  cursorpos: { type: :integer, example: 12, description: 'Coalesced to 0 when null' },
                  is_write: { type: :boolean, nullable: true, example: true },
                  project: { type: :string, nullable: true, example: 'hackatime' },
                  language: { type: :string, nullable: true, example: 'Ruby' },
                  entity: { type: :string, nullable: true, example: 'app/models/user.rb' },
                  branch: { type: :string, nullable: true, example: 'main' },
                  category: { type: :string, nullable: true, example: 'coding' },
                  editor: { type: :string, nullable: true, example: 'VS Code' },
                  machine: { type: :string, nullable: true, example: 'Orpheus-MacBook-Pro' },
                  user_agent: { type: :string, nullable: true, example: 'wakatime/v1.115.2 (darwin-24.6.0) go1.23 vscode/1.96.0' },
                  ip_address: { type: :string, nullable: true, example: '203.0.113.7' },
                  lines: { type: :integer, nullable: true, example: 350 },
                  source_type: { type: :string, example: 'direct_entry' }
                }
              }
            },
            total_count: { type: :integer, example: 15234 },
            has_more: { type: :boolean, example: true }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'hb_user')
          EmailAddress.create!(user: u, email: 'hb@example.com')
          u
        end
        let(:user_id) { user.id }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:project) { nil }
        let(:language) { nil }
        let(:entity) { nil }
        let(:editor) { nil }
        let(:machine) { nil }
        let(:limit) { 10 }
        let(:offset) { 0 }
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { '0' }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:project) { nil }
        let(:language) { nil }
        let(:entity) { nil }
        let(:editor) { nil }
        let(:machine) { nil }
        let(:limit) { 10 }
        let(:offset) { 0 }
        run_test!
      end

      response(422, 'invalid date filter') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'hb_user_invalid_date')
          EmailAddress.create!(user: u, email: 'hb-invalid@example.com')
          u
        end
        let(:user_id) { user.id }
        let(:start_date) { 'not-a-date' }
        let(:end_date) { nil }
        let(:project) { nil }
        let(:language) { nil }
        let(:entity) { nil }
        let(:editor) { nil }
        let(:machine) { nil }
        let(:limit) { 10 }
        let(:offset) { 0 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/admin/v1/heartbeats/by_user_agent_segment' do
    get('Get heartbeats matching a user_agent segment') do
      tags 'Admin Utils'
      description 'Returns heartbeats whose user_agent contains the given substring (e.g. "Godot_Super-Wakatime/2.0.0"). Useful for monitoring how a specific editor/plugin behaves over time. Use count_only=true to avoid streaming rows when only the total is needed.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :segment, in: :query, type: :string, required: true, description: 'Substring of user_agent to match (case-insensitive). Min length 3.'
      parameter name: :user_id, in: :query, type: :string, required: false, description: 'Optional user ID to scope the query to a single user.'
      parameter name: :start_date, in: :query, type: :string, required: false, description: 'Start date (YYYY-MM-DD or epoch seconds)'
      parameter name: :end_date, in: :query, type: :string, required: false, description: 'End date (YYYY-MM-DD or epoch seconds)'
      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Page size (default 1000, max 5000)'
      parameter name: :offset, in: :query, type: :integer, required: false, description: 'Pagination offset'
      parameter name: :count_only, in: :query, type: :boolean, required: false, description: 'If true, return only total_count and skip row payload'

      response(200, 'successful with matching rows') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:hb_user) do
          u = User.create!(username: 'hb_segment_user')
          EmailAddress.create!(user: u, email: 'hb-segment@example.com')
          u
        end
        before do
          Heartbeat.create!(
            user: hb_user,
            time: Time.current.to_i,
            project: 'demo',
            language: 'GDScript',
            editor: 'Godot',
            source_type: :direct_entry,
            branch: 'main',
            category: 'coding',
            is_write: true,
            user_agent: 'Godot/4.2 Godot_Super-Wakatime/2.0.0',
            operating_system: 'linux',
            machine: 'test-machine'
          )
        end
        let(:segment) { 'Godot_Super-Wakatime' }
        let(:user_id) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:limit) { 10 }
        let(:offset) { 0 }
        let(:count_only) { nil }
        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['heartbeats'].size).to eq(1)
          expect(body['heartbeats'].first['user_agent']).to include('Godot_Super-Wakatime')
          expect(body['has_more']).to eq(false)
        end
      end

      response(200, 'count_only returns total only') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:hb_user) do
          u = User.create!(username: 'hb_segment_count_user')
          EmailAddress.create!(user: u, email: 'hb-segment-count@example.com')
          u
        end
        before do
          2.times do |i|
            Heartbeat.create!(
              user: hb_user,
              time: Time.current.to_i - i,
              project: 'demo',
              language: 'GDScript',
              editor: 'Godot',
              source_type: :direct_entry,
              branch: 'main',
              category: 'coding',
              is_write: true,
              user_agent: 'Godot/4.2 Godot_Super-Wakatime/2.0.0',
              operating_system: 'linux',
              machine: 'test-machine'
            )
          end
        end
        let(:segment) { 'Godot_Super-Wakatime' }
        let(:user_id) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:limit) { nil }
        let(:offset) { nil }
        let(:count_only) { true }
        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['total_count']).to eq(2)
          expect(body).not_to have_key('heartbeats')
        end
      end

      response(422, 'segment too short') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:segment) { 'ab' }
        let(:user_id) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:limit) { nil }
        let(:offset) { nil }
        let(:count_only) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(200, 'successful') do
        schema oneOf: [
          {
            type: :object,
            properties: {
              segment: { type: :string, example: 'Godot_Super-Wakatime' },
              limit: { type: :integer, example: 10 },
              offset: { type: :integer, example: 0 },
              heartbeats: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, example: 987654 },
                    user_id: { type: :integer, example: 42 },
                    time: { type: :number, example: 1710946200.0 },
                    project: { type: :string, nullable: true, example: 'demo' },
                    language: { type: :string, nullable: true, example: 'GDScript' },
                    entity: { type: :string, nullable: true, example: 'res://player.gd' },
                    branch: { type: :string, nullable: true, example: 'main' },
                    category: { type: :string, nullable: true, example: 'coding' },
                    editor: { type: :string, nullable: true, example: 'Godot' },
                    machine: { type: :string, nullable: true, example: 'Orpheus-MacBook-Pro' },
                    operating_system: { type: :string, nullable: true, example: 'Mac' },
                    user_agent: { type: :string, nullable: true, example: 'Godot/4.2 Godot_Super-Wakatime/2.0.0' },
                    ip_address: { type: :string, nullable: true, example: '203.0.113.7' },
                    is_write: { type: :boolean, nullable: true, example: true },
                    lineno: { type: :integer, nullable: true, example: 42 },
                    cursorpos: { type: :integer, nullable: true, example: 12 },
                    lines: { type: :integer, nullable: true, example: 350 },
                    source_type: { type: :string, nullable: true, example: 'direct_entry' }
                  }
                }
              },
              has_more: { type: :boolean, example: false }
            }
          },
          {
            type: :object,
            description: 'Returned when count_only=true',
            additionalProperties: false,
            required: [ 'segment', 'total_count' ],
            properties: {
              segment: { type: :string, example: 'Godot_Super-Wakatime' },
              total_count: { type: :integer, example: 2 }
            }
          }
        ]

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:hb_user_doc) do
          u = User.create!(username: 'hb_segment_doc_user')
          EmailAddress.create!(user: u, email: 'hb-segment-doc@example.com')
          u
        end
        before do
          Heartbeat.create!(
            user: hb_user_doc,
            time: Time.current.to_i,
            project: 'demo',
            language: 'GDScript',
            editor: 'Godot',
            source_type: :direct_entry,
            branch: 'main',
            category: 'coding',
            is_write: true,
            user_agent: 'Godot/4.2 Godot_Super-Wakatime/2.0.0',
            operating_system: 'linux',
            machine: 'test-machine'
          )
        end
        let(:segment) { 'Godot_Super-Wakatime' }
        let(:user_id) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:limit) { 10 }
        let(:offset) { 0 }
        let(:count_only) { nil }
        run_test!
      end

      response(422, 'missing segment') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:segment) { '' }
        let(:user_id) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:limit) { nil }
        let(:offset) { nil }
        let(:count_only) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/heartbeat_values' do
    get('Get heartbeat values') do
      tags 'Admin Utils'
      description 'Get specific values from heartbeats.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'User ID. Either user_id or id may be supplied.'
      parameter name: :id, in: :query, type: :string, required: false, description: 'Alias for user_id. If both id and user_id are supplied, id takes precedence.'
      parameter name: :field, in: :query, schema: {
        type: :string,
        enum: %w[projects languages entities branches categories editors machines user_agents ips]
      }, description: 'Field to retrieve distinct values for. Must be one of the allowed values; an unknown value returns 422.'
      parameter name: :start_date, in: :query, type: :string, description: 'Start date (YYYY-MM-DD or timestamp)'
      parameter name: :end_date, in: :query, type: :string, description: 'End date (YYYY-MM-DD or timestamp)'
      parameter name: :limit, in: :query, type: :integer, description: 'Limit results (default 5000, max 5000)'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            user_id: { type: :integer, example: 42 },
            field: { type: :string, example: 'projects' },
            values: { type: :array, items: { type: :string, example: 'hackatime' } },
            count: { type: :integer, example: 12 }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'projects_user')
          EmailAddress.create!(user: u, email: 'projects@example.com')
          u
        end
        let(:user_id) { user.id }
        let(:field) { 'projects' }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:limit) { 5000 }
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { '0' }
        let(:field) { 'projects' }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:limit) { 5000 }
        run_test!
      end

      response(422, 'invalid date filter or invalid field — Returned with "invalid date filter" when start_date/end_date cannot be parsed, or "invalid field" when field is not one of the allowed values.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'projects_invalid')
          EmailAddress.create!(user: u, email: 'projects-invalid@example.com')
          u
        end
        let(:user_id) { user.id }
        let(:field) { 'projects' }
        let(:start_date) { 'not-a-date' }
        let(:end_date) { nil }
        let(:limit) { 5000 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(422, 'invalid field — Returned ("invalid field") when field is not one of the allowed values.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'proj_bad_field')
          EmailAddress.create!(user: u, email: 'projects-invalid-field@example.com')
          u
        end
        let(:user_id) { user.id }
        let(:field) { 'not_a_field' }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:limit) { 5000 }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/get_users_by_ip' do
    get('Get users by IP') do
      tags 'Admin Utils'
      description 'Find users associated with an IP address.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :ip, in: :query, type: :string, description: 'IP Address'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:ip) { '127.0.0.1' }
        schema type: :object,
          properties: {
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user_id: { type: :integer, example: 42 },
                  ip_address: { type: :string, example: '203.0.113.7' },
                  machine: { type: :string, nullable: true, example: 'Orpheus-MacBook-Pro' },
                  user_agent: { type: :string, nullable: true, example: 'wakatime/v1.115.2 (darwin-24.6.0) go1.23 vscode/1.96.0' }
                }
              }
            }
          }
        run_test!
      end

      response(422, 'missing ip — Returned ("bro dont got the ip") when the ip parameter is blank.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:ip) { '' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/get_users_by_machine' do
    get('Get users by machine') do
      tags 'Admin Utils'
      description 'Find users associated with a machine ID.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :machine, in: :query, type: :string, description: 'Machine ID'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:machine) { 'some-machine-id' }
        schema type: :object,
          properties: {
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user_id: { type: :integer, example: 42 },
                  machine: { type: :string, example: 'Orpheus-MacBook-Pro' }
                }
              }
            }
          }
        run_test!
      end

      response(422, 'missing machine — Returned ("bro dont got the machine") when the machine parameter is blank.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:machine) { '' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/stats' do
    get('Get admin user stats') do
      tags 'Admin Utils'
      description 'Get detailed stats for a user (Admin view). When start_date/end_date are provided, heartbeats are filtered to that range; otherwise the single date param (default: current date) is used.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'User ID. Either user_id or id may be supplied.'
      parameter name: :id, in: :query, type: :string, required: false, description: 'Alias for user_id. If both id and user_id are supplied, id takes precedence.'
      parameter name: :start_date, in: :query, type: :string, required: false, description: 'Start date (YYYY-MM-DD or epoch seconds). When present (with or without end_date), defines the time range and overrides the date param. Defaults to 10 years ago.'
      parameter name: :end_date, in: :query, type: :string, required: false, description: 'End date (YYYY-MM-DD or epoch seconds). Defaults to end of the current day.'
      parameter name: :date, in: :query, schema: { type: :string, format: :date }, required: false, description: 'Single day (YYYY-MM-DD) to scope stats to. Only used when neither start_date nor end_date is supplied. Defaults to the current date.'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'stats_user')
          EmailAddress.create!(user: u, email: 'stats@example.com')
          u
        end
        let(:user_id) { user.id }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:date) { nil }
        schema type: :object,
          properties: {
            user_id: { type: :integer, example: 42 },
            username: { type: :string, example: 'orpheus' },
            start_date: { type: :string, format: :date, example: '2024-03-20' },
            end_date: { type: :string, format: :date, example: '2024-03-20' },
            timezone: { type: :string, nullable: true, example: 'America/New_York' },
            total_heartbeats: { type: :integer, example: 152 },
            total_duration: { type: :number, example: 7200.0 },
            heartbeats: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, example: 987654 },
                  time: { type: :string, example: '1710946200.0' },
                  created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
                  project: { type: :string, nullable: true, example: 'hackatime' },
                  branch: { type: :string, nullable: true, example: 'main' },
                  category: { type: :string, nullable: true, example: 'coding' },
                  dependencies: { type: :string, nullable: true, example: 'rails,sidekiq' },
                  editor: { type: :string, nullable: true, example: 'VS Code' },
                  entity: { type: :string, nullable: true, example: 'app/models/user.rb' },
                  language: { type: :string, nullable: true, example: 'Ruby' },
                  machine: { type: :string, nullable: true, example: 'Orpheus-MacBook-Pro' },
                  operating_system: { type: :string, nullable: true, example: 'Mac' },
                  type: { type: :string, nullable: true, example: 'file' },
                  user_agent: { type: :string, nullable: true, example: 'wakatime/v1.115.2 (darwin-24.6.0) go1.23 vscode/1.96.0' },
                  line_additions: { type: :integer, nullable: true, example: 8 },
                  line_deletions: { type: :integer, nullable: true, example: 3 },
                  lineno: { type: :integer, nullable: true, example: 42 },
                  lines: { type: :integer, nullable: true, example: 350 },
                  cursorpos: { type: :integer, nullable: true, example: 12 },
                  project_root_count: { type: :integer, nullable: true, example: 4 },
                  is_write: { type: :boolean, nullable: true, example: true },
                  source_type: { type: :string, nullable: true, example: 'direct_entry' },
                  ip_address: { type: :string, nullable: true, example: '203.0.113.7' }
                }
              }
            }
          }
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { '0' }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:date) { nil }
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/projects' do
    get('Get admin user projects') do
      tags 'Admin Utils'
      description 'Get projects for a user (Admin view).'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'User ID. Either user_id or id may be supplied.'
      parameter name: :id, in: :query, type: :string, required: false, description: 'Alias for user_id. If both id and user_id are supplied, id takes precedence.'
      parameter name: :start_date, in: :query, type: :string, required: false, description: 'Start date (YYYY-MM-DD or epoch seconds). When start_date or end_date is present, heartbeats are filtered to that range. Defaults to 10 years ago.'
      parameter name: :end_date, in: :query, type: :string, required: false, description: 'End date (YYYY-MM-DD or epoch seconds). Defaults to end of the current day.'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'hb_values_user')
          EmailAddress.create!(user: u, email: 'hb_vals@example.com')
          u
        end
        let(:user_id) { user.id }
        let(:start_date) { nil }
        let(:end_date) { nil }
        schema type: :object,
          properties: {
            user_id: { type: :integer, example: 42 },
            username: { type: :string, example: 'orpheus' },
            total_projects: { type: :integer, example: 12 },
            projects: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  name: { type: :string, nullable: true, example: 'hackatime' },
                  total_heartbeats: { type: :integer, example: 4821 },
                  total_duration: { type: :number, example: 86400.0 },
                  first_heartbeat: { type: :number, nullable: true, example: 1704067200.0 },
                  last_heartbeat: { type: :number, nullable: true, example: 1710946200.0 },
                  languages: { type: :array, items: { type: :string, example: 'Ruby' } },
                  repo: { type: :string, nullable: true, example: 'https://github.com/hackclub/hackatime' },
                  repo_mapping_id: { type: :integer, nullable: true, example: 314 },
                  archived: { type: :boolean, example: false }
                }
              }
            }
          }
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { '0' }
        let(:start_date) { nil }
        let(:end_date) { nil }
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/trust_logs' do
    get('Get user trust logs') do
      tags 'Admin Utils'
      description 'Get trust level audit logs for a user.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'User ID. Either user_id or id may be supplied.'
      parameter name: :id, in: :query, type: :string, required: false, description: 'Alias for user_id. If both id and user_id are supplied, id takes precedence.'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { '1' }
        schema type: :object,
          properties: {
            trust_logs: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, example: 5012 },
                  previous_trust_level: { type: :string, nullable: true, example: 'blue' },
                  new_trust_level: { type: :string, example: 'red' },
                  reason: { type: :string, nullable: true, example: 'self-reported heartbeats' },
                  notes: { type: :string, nullable: true, example: 'Reviewed flagged activity' },
                  created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
                  changed_by: {
                    type: :object,
                    properties: {
                      id: { type: :integer, example: 1 },
                      username: { type: :string, example: 'orpheus' },
                      display_name: { type: :string, example: 'orpheus' },
                      admin_level: { type: :string, example: 'superadmin' }
                    }
                  }
                }
              }
            }
          }
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/get_user_by_email' do
    post('Get user by email') do
      tags 'Admin Utils'
      description 'Lookup user by email (POST).'
      security [ AdminToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        required: %w[email],
        properties: {
          email: { type: :string, example: 'orpheus@hackclub.com', description: 'Email address to look up. Required in practice; a blank email returns 422.' }
        }
      }

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_with_email) do
          u = User.create!(username: 'email_lookup_user')
          EmailAddress.create!(user: u, email: 'lookup@example.com')
          u
        end
        before { user_with_email }
        let(:payload) { { email: 'lookup@example.com' } }
        schema type: :object,
          properties: {
            user_id: { type: :integer, example: 42 }
          }
        run_test!
      end

      response(422, 'missing email — Returned ("bro dont have a email") when the email is blank.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { email: '' } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(404, 'email not found — Returned ("email not found") when no email address matches.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { email: 'does-not-exist@example.com' } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/search_fuzzy' do
    post('Fuzzy search users') do
      tags 'Admin Utils'
      description 'Search users by fuzzy matching.'
      security [ AdminToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        required: %w[query],
        properties: {
          query: { type: :string, example: 'orpheus', description: 'Search query. Required in practice; a blank query returns 422.' }
        }
      }

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { query: 'test' } }
        schema type: :object,
          properties: {
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, example: 42 },
                  username: { type: :string, nullable: true, example: 'orpheus' },
                  slack_username: { type: :string, nullable: true, example: 'orpheus' },
                  github_username: { type: :string, nullable: true, example: 'orpheus' },
                  slack_avatar_url: { type: :string, nullable: true, example: 'https://avatars.slack-edge.com/2024-03-20/orpheus_512.png' },
                  github_avatar_url: { type: :string, nullable: true, example: 'https://avatars.githubusercontent.com/u/12345?v=4' },
                  email: { type: :string, example: 'orpheus@hackclub.com' },
                  rank_score: { type: :number, example: 0.87 }
                }
              }
            }
          }
        run_test!
      end

      response(422, 'missing query — Returned ("bro dont have a query") when the query is blank.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { query: '' } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/convict' do
    post('Convict user') do
      tags 'Admin Utils'
      description 'Mark a user as convicted/banned by setting their trust level. Requires admin write permissions and authority to change the target user trust level.'
      security [ AdminToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        required: %w[user_id reason trust_level],
        properties: {
          user_id: { type: :integer, example: 42, description: 'Target user ID. id is also accepted as an alias.' },
          reason: { type: :string, example: 'self-reported heartbeats', description: 'Required justification; a blank reason returns 422.' },
          trust_level: { type: :string, enum: %w[blue red green yellow], example: 'red', description: 'Required. New trust level; must be a valid trust level key or a 422 is returned.' },
          notes: { type: :string, example: 'Reviewed flagged activity', description: 'Optional notes stored on the audit log.' }
        }
      }

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'convict_me')
          EmailAddress.create!(user: u, email: 'convict@example.com')
          u
        end
        let(:payload) { { user_id: user.id, reason: 'spam', trust_level: 'red' } }
        schema type: :object,
          properties: {
            success: { type: :boolean, example: true },
            message: { type: :string, example: 'User convicted successfully' },
            user: {
              type: :object,
              properties: {
                id: { type: :integer, example: 42 },
                username: { type: :string, example: 'orpheus' },
                trust_level: { type: :string, example: 'red' },
                updated_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' }
              }
            },
            audit_log: {
              type: :object,
              properties: {
                changed_by: { type: :string, example: 'orpheus' },
                reason: { type: :string, example: 'self-reported heartbeats' },
                notes: { type: :string, nullable: true, example: 'Reviewed flagged activity' },
                timestamp: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' }
              }
            }
          }
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { user_id: 0, reason: 'spam', trust_level: 'red' } }
        run_test!
      end

      response(422, 'invalid request — Returned with "you cant punish a mortal and not justify your actions" when reason is blank, "read the docs you idiot" when trust_level is not a valid trust level, or "no perms lmaooo" when the trust level change fails.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'convict_invalid')
          EmailAddress.create!(user: u, email: 'convict-invalid@example.com')
          u
        end
        let(:payload) { { user_id: user.id, reason: 'spam', trust_level: 'not_a_level' } }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
