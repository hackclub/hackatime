require 'swagger_helper'

RSpec.describe 'Admin::Timeline', type: :request, openapi_spec: 'admin/swagger.yaml' do
  path '/api/admin/v1/timeline' do
    get('Get timeline') do
      tags 'Admin Timeline'
      description 'Get timeline events including coding activity and commits for selected users.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :date, in: :query, schema: { type: :string, format: :date }, description: 'Date for the timeline (YYYY-MM-DD)'
      parameter name: :user_ids, in: :query, type: :string, description: 'Comma-separated list of User IDs'
      parameter name: :slack_uids, in: :query, type: :string, description: 'Comma-separated list of Slack User IDs'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            date: { type: :string, format: :date, example: '2024-03-20' },
            next_date: { type: :string, format: :date, example: '2024-03-21' },
            prev_date: { type: :string, format: :date, example: '2024-03-19' },
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user: {
                    type: :object,
                    properties: {
                      id: { type: :integer, example: 42 },
                      username: { type: :string, example: 'orpheus' },
                      display_name: { type: :string, nullable: true, example: 'orpheus' },
                      slack_username: { type: :string, nullable: true, example: 'orpheus' },
                      github_username: { type: :string, nullable: true, example: 'orpheus' },
                      timezone: { type: :string, nullable: true, example: 'America/New_York' },
                      avatar_url: { type: :string, nullable: true, example: 'https://avatars.slack-edge.com/2024-03-20/orpheus_512.png' }
                    }
                  },
                  spans: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        start_time: { type: :number, format: :float, example: 1710946200.0 },
                        end_time: { type: :number, format: :float, example: 1710949800.0 },
                        duration: { type: :number, format: :float, example: 3600.0 },
                        files_edited: { type: :array, items: { type: :string, example: 'app/models/user.rb' } },
                        projects_edited_details: {
                          type: :array,
                          items: {
                            type: :object,
                            properties: {
                              name: { type: :string, example: 'hackatime' },
                              repo_url: { type: :string, nullable: true, example: 'https://github.com/hackclub/hackatime' }
                            }
                          }
                        },
                        editors: { type: :array, items: { type: :string, example: 'VS Code' } },
                        languages: { type: :array, items: { type: :string, example: 'Ruby' } }
                      }
                    }
                  },
                  total_coded_time: { type: :number, format: :float, example: 7200.0 }
                }
              }
            },
            commit_markers: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user_id: { type: :integer, example: 42 },
                  timestamp: { type: :number, format: :float, example: 1710948000.0 },
                  additions: { type: :integer, nullable: true, example: 120 },
                  deletions: { type: :integer, nullable: true, example: 18 },
                  github_url: { type: :string, nullable: true, example: 'https://github.com/hackclub/hackatime/commit/a1b2c3d' }
                }
              }
            }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:date) { Time.current.to_date.to_s }
        let(:user_ids) { User.first&.id.to_s }
        let(:slack_uids) { nil }
        schema type: :object,
          properties: {
            date: { type: :string, format: :date, example: '2024-03-20' },
            next_date: { type: :string, format: :date, example: '2024-03-21' },
            prev_date: { type: :string, format: :date, example: '2024-03-19' },
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user: {
                    type: :object,
                    properties: {
                      id: { type: :integer, example: 42 },
                      username: { type: :string, example: 'orpheus' },
                      display_name: { type: :string, nullable: true, example: 'orpheus' },
                      slack_username: { type: :string, nullable: true, example: 'orpheus' },
                      github_username: { type: :string, nullable: true, example: 'orpheus' },
                      timezone: { type: :string, nullable: true, example: 'America/New_York' },
                      avatar_url: { type: :string, nullable: true, example: 'https://avatars.slack-edge.com/2024-03-20/orpheus_512.png' }
                    }
                  },
                  spans: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        start_time: { type: :number, format: :float, example: 1710946200.0 },
                        end_time: { type: :number, format: :float, example: 1710949800.0 },
                        duration: { type: :number, format: :float, example: 3600.0 },
                        files_edited: { type: :array, items: { type: :string, example: 'app/models/user.rb' } },
                        projects_edited_details: {
                          type: :array,
                          items: {
                            type: :object,
                            properties: {
                              name: { type: :string, example: 'hackatime' },
                              repo_url: { type: :string, nullable: true, example: 'https://github.com/hackclub/hackatime' }
                            }
                          }
                        },
                        editors: { type: :array, items: { type: :string, example: 'VS Code' } },
                        languages: { type: :array, items: { type: :string, example: 'Ruby' } }
                      }
                    }
                  },
                  total_coded_time: { type: :number, format: :float, example: 7200.0 }
                }
              }
            },
            commit_markers: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user_id: { type: :integer, example: 42 },
                  timestamp: { type: :number, format: :float, example: 1710948000.0 },
                  additions: { type: :integer, nullable: true, example: 120 },
                  deletions: { type: :integer, nullable: true, example: 18 },
                  github_url: { type: :string, nullable: true, example: 'https://github.com/hackclub/hackatime/commit/a1b2c3d' }
                }
              }
            }
          }
        run_test!
      end

      response(422, 'invalid date format') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:date) { 'not-a-date' }
        let(:user_ids) { nil }
        let(:slack_uids) { nil }
        schema type: :object,
          properties: {
            error: { type: :string, example: 'Invalid date format' }
          },
          required: [ 'error' ]
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-admin-key" }
        let(:date) { Time.current.to_date.to_s }
        let(:user_ids) { nil }
        let(:slack_uids) { nil }
        run_test!
      end
    end
  end

  path '/api/admin/v1/timeline/search_users' do
    get('Search timeline users') do
      tags 'Admin Timeline'
      description 'Search users specifically for the timeline view by username, slack username, ID, or email.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :query, in: :query, type: :string, description: 'Search query'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:query) { User.first&.username || 'admin' }
        schema type: :object,
          properties: {
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, example: 42 },
                  display_name: { type: :string, nullable: true, example: 'orpheus' },
                  avatar_url: { type: :string, nullable: true, example: 'https://avatars.slack-edge.com/2024-03-20/orpheus_512.png' }
                }
              }
            }
          }
        run_test!
      end

      response(422, 'unprocessable entity') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:query) { '' }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-admin-key" }
        let(:query) { 'admin' }
        run_test!
      end
    end
  end

  path '/api/admin/v1/timeline/leaderboard_users' do
    get('Get leaderboard users for timeline') do
      tags 'Admin Timeline'
      description 'Get users who should appear on the timeline leaderboard based on recent activity.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :period, in: :query, schema: { type: :string, enum: [ 'daily', 'last_7_days' ] }, description: 'Leaderboard period'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:period) { 'last_7_days' }
        schema type: :object,
          properties: {
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, example: 42 },
                  display_name: { type: :string, nullable: true, example: 'orpheus' },
                  avatar_url: { type: :string, nullable: true, example: 'https://avatars.slack-edge.com/2024-03-20/orpheus_512.png' }
                }
              }
            }
          }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-admin-key" }
        let(:period) { 'last_7_days' }
        run_test!
      end
    end
  end
end
