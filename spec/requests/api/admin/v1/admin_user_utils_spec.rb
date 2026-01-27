require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::UserUtils', type: :request do
  path '/api/admin/v1/user/info_batch' do
    get('Get user info batch') do
      tags 'Admin Utils'
      description 'Get info for multiple users.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :ids, in: :query, type: :array, items: { type: :integer }, description: 'User IDs'

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
