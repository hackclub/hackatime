require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::UserUtils', type: :request do
  path '/api/admin/v1/user/info_batch' do
    get('Get user info batch') do
      tags 'Admin Utils'
      description 'Get info for multiple users.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :ids, in: :query, schema: { type: :array, items: { type: :integer } }, description: 'User IDs'

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
        let(:ids) { [ u1.id, u2.id ] }
        schema type: :object,
          properties: {
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  username: { type: :string },
                  display_name: { type: :string },
                  slack_uid: { type: :string, nullable: true },
                  slack_username: { type: :string, nullable: true },
                  github_username: { type: :string, nullable: true },
                  timezone: { type: :string, nullable: true },
                  country_code: { type: :string, nullable: true },
                  trust_level: { type: :string },
                  avatar_url: { type: :string, nullable: true },
                  slack_avatar_url: { type: :string, nullable: true },
                  github_avatar_url: { type: :string, nullable: true }
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
    end
  end

  path '/api/admin/v1/user/info' do
    get('Get user info') do
      tags 'Admin Utils'
      description 'Get detailed info for a single user.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'User ID'

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
                id: { type: :integer },
                username: { type: :string },
                display_name: { type: :string },
                slack_uid: { type: :string, nullable: true },
                slack_username: { type: :string, nullable: true },
                github_username: { type: :string, nullable: true },
                timezone: { type: :string, nullable: true },
                country_code: { type: :string, nullable: true },
                admin_level: { type: :string },
                trust_level: { type: :string },
                suspected: { type: :boolean },
                banned: { type: :boolean },
                created_at: { type: :string, format: :date_time },
                updated_at: { type: :string, format: :date_time },
                last_heartbeat_at: { type: :number, nullable: true },
                email_addresses: { type: :array, items: { type: :string } },
                api_keys_count: { type: :integer },
                stats: {
                  type: :object,
                  properties: {
                    total_heartbeats: { type: :integer },
                    total_coding_time: { type: :number },
                    languages_used: { type: :integer },
                    projects_worked_on: { type: :integer },
                    days_active: { type: :integer }
                  }
                }
              }
            }
          }
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

      parameter name: :user_id, in: :query, type: :string, description: 'User ID'
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
            user_id: { type: :integer },
            heartbeats: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  time: { type: :number },
                  lineno: { type: :integer, nullable: true },
                  cursorpos: { type: :integer, nullable: true },
                  is_write: { type: :boolean, nullable: true },
                  project: { type: :string, nullable: true },
                  language: { type: :string, nullable: true },
                  entity: { type: :string, nullable: true },
                  branch: { type: :string, nullable: true },
                  category: { type: :string, nullable: true },
                  editor: { type: :string, nullable: true },
                  machine: { type: :string, nullable: true },
                  user_agent: { type: :string, nullable: true },
                  ip_address: { type: :string, nullable: true },
                  lines: { type: :integer, nullable: true },
                  source_type: { type: :string, nullable: true }
                }
              }
            },
            total_count: { type: :integer },
            has_more: { type: :boolean }
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
              segment: { type: :string },
              limit: { type: :integer },
              offset: { type: :integer },
              heartbeats: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    user_id: { type: :integer },
                    time: { type: :number },
                    project: { type: :string, nullable: true },
                    language: { type: :string, nullable: true },
                    entity: { type: :string, nullable: true },
                    branch: { type: :string, nullable: true },
                    category: { type: :string, nullable: true },
                    editor: { type: :string, nullable: true },
                    machine: { type: :string, nullable: true },
                    operating_system: { type: :string, nullable: true },
                    user_agent: { type: :string, nullable: true },
                    ip_address: { type: :string, nullable: true },
                    is_write: { type: :boolean, nullable: true },
                    lineno: { type: :integer, nullable: true },
                    cursorpos: { type: :integer, nullable: true },
                    lines: { type: :integer, nullable: true },
                    source_type: { type: :string, nullable: true }
                  }
                }
              },
              has_more: { type: :boolean }
            }
          },
          {
            type: :object,
            description: 'Returned when count_only=true',
            additionalProperties: false,
            required: [ 'segment', 'total_count' ],
            properties: {
              segment: { type: :string },
              total_count: { type: :integer }
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

      parameter name: :user_id, in: :query, type: :string, description: 'User ID'
      parameter name: :field, in: :query, type: :string, description: 'Field to retrieve (projects, languages, etc.)'
      parameter name: :start_date, in: :query, type: :string, description: 'Start date (YYYY-MM-DD or timestamp)'
      parameter name: :end_date, in: :query, type: :string, description: 'End date (YYYY-MM-DD or timestamp)'
      parameter name: :limit, in: :query, type: :integer, description: 'Limit results'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            user_id: { type: :integer },
            field: { type: :string },
            values: { type: :array, items: { type: :string } },
            count: { type: :integer }
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

      response(422, 'invalid date filter') do
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
                  user_id: { type: :integer },
                  ip_address: { type: :string },
                  machine: { type: :string, nullable: true },
                  user_agent: { type: :string, nullable: true }
                }
              }
            }
          }
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
                  user_id: { type: :integer },
                  machine: { type: :string }
                }
              }
            }
          }
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/stats' do
    get('Get admin user stats') do
      tags 'Admin Utils'
      description 'Get detailed stats for a user (Admin view).'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'User ID'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'stats_user')
          EmailAddress.create!(user: u, email: 'stats@example.com')
          u
        end
        let(:user_id) { user.id }
        schema type: :object,
          properties: {
            user_id: { type: :integer },
            username: { type: :string },
            date: { type: :string, format: :date_time },
            timezone: { type: :string, nullable: true },
            total_heartbeats: { type: :integer },
            total_duration: { type: :number },
            heartbeats: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  time: { type: :string },
                  created_at: { type: :string, format: :date_time },
                  project: { type: :string, nullable: true },
                  branch: { type: :string, nullable: true },
                  category: { type: :string, nullable: true },
                  dependencies: { type: :string, nullable: true },
                  editor: { type: :string, nullable: true },
                  entity: { type: :string, nullable: true },
                  language: { type: :string, nullable: true },
                  machine: { type: :string, nullable: true },
                  operating_system: { type: :string, nullable: true },
                  type: { type: :string, nullable: true },
                  user_agent: { type: :string, nullable: true },
                  line_additions: { type: :integer, nullable: true },
                  line_deletions: { type: :integer, nullable: true },
                  lineno: { type: :integer, nullable: true },
                  lines: { type: :integer, nullable: true },
                  cursorpos: { type: :integer, nullable: true },
                  project_root_count: { type: :integer, nullable: true },
                  is_write: { type: :boolean, nullable: true },
                  source_type: { type: :string, nullable: true },
                  ysws_program: { type: :string, nullable: true },
                  ip_address: { type: :string, nullable: true }
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
    end
  end

  path '/api/admin/v1/user/projects' do
    get('Get admin user projects') do
      tags 'Admin Utils'
      description 'Get projects for a user (Admin view).'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'User ID'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'hb_values_user')
          EmailAddress.create!(user: u, email: 'hb_vals@example.com')
          u
        end
        let(:user_id) { user.id }
        let(:field) { 'projects' }
        schema type: :object,
          properties: {
            user_id: { type: :integer },
            username: { type: :string },
            total_projects: { type: :integer },
            projects: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  name: { type: :string, nullable: true },
                  total_heartbeats: { type: :integer },
                  total_duration: { type: :number },
                  first_heartbeat: { type: :number, nullable: true },
                  last_heartbeat: { type: :number, nullable: true },
                  languages: { type: :array, items: { type: :string } },
                  repo: { type: :string, nullable: true },
                  repo_mapping_id: { type: :integer, nullable: true },
                  archived: { type: :boolean }
                }
              }
            }
          }
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { '0' }
        let(:field) { 'projects' }
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

      parameter name: :user_id, in: :query, type: :string, description: 'User ID'

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
                  id: { type: :integer },
                  previous_trust_level: { type: :string, nullable: true },
                  new_trust_level: { type: :string },
                  reason: { type: :string, nullable: true },
                  notes: { type: :string, nullable: true },
                  created_at: { type: :string, format: :date_time },
                  changed_by: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      username: { type: :string },
                      display_name: { type: :string },
                      admin_level: { type: :string }
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
        properties: {
          email: { type: :string }
        }
      }

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { email: 'test@example.com' } }
        schema type: :object,
          properties: {
            user_id: { type: :integer }
          }
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
        properties: {
          query: { type: :string }
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
                  id: { type: :integer },
                  username: { type: :string },
                  slack_username: { type: :string, nullable: true },
                  github_username: { type: :string, nullable: true },
                  slack_avatar_url: { type: :string, nullable: true },
                  github_avatar_url: { type: :string, nullable: true },
                  email: { type: :string },
                  rank_score: { type: :number }
                }
              }
            }
          }
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/convict' do
    post('Convict user') do
      tags 'Admin Utils'
      description 'Mark a user as convicted/banned.'
      security [ AdminToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          user_id: { type: :integer },
          reason: { type: :string }
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
            success: { type: :boolean },
            message: { type: :string },
            user: {
              type: :object,
              properties: {
                id: { type: :integer },
                username: { type: :string },
                trust_level: { type: :string },
                updated_at: { type: :string, format: :date_time }
              }
            },
            audit_log: {
              type: :object,
              properties: {
                changed_by: { type: :string },
                reason: { type: :string },
                notes: { type: :string, nullable: true },
                timestamp: { type: :string, format: :date_time }
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
    end
  end
end
