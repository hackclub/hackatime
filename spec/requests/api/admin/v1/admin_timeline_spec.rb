require 'swagger_helper'

RSpec.describe 'Admin::Timeline', type: :request do
  path '/api/admin/v1/timeline' do
    get('Get timeline') do
      tags 'Admin Timeline'
      description 'Get timeline events including coding activity and commits for selected users.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :date, in: :query, type: :string, format: :date, description: 'Date for the timeline (YYYY-MM-DD)'
      parameter name: :user_ids, in: :query, type: :string, description: 'Comma-separated list of User IDs'
      parameter name: :slack_uids, in: :query, type: :string, description: 'Comma-separated list of Slack User IDs'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            date: { type: :string, format: :date },
            next_date: { type: :string, format: :date },
            prev_date: { type: :string, format: :date },
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      username: { type: :string },
                      display_name: { type: :string, nullable: true },
                      slack_username: { type: :string, nullable: true },
                      github_username: { type: :string, nullable: true },
                      timezone: { type: :string, nullable: true },
                      avatar_url: { type: :string, nullable: true }
                    }
                  },
                  spans: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        start_time: { type: :number, format: :float },
                        end_time: { type: :number, format: :float },
                        duration: { type: :number, format: :float },
                        files_edited: { type: :array, items: { type: :string } },
                        projects_edited_details: {
                          type: :array,
                          items: {
                            type: :object,
                            properties: {
                              name: { type: :string },
                              repo_url: { type: :string, nullable: true }
                            }
                          }
                        },
                        editors: { type: :array, items: { type: :string } },
                        languages: { type: :array, items: { type: :string } }
                      }
                    }
                  },
                  total_coded_time: { type: :number, format: :float }
                }
              }
            },
            commit_markers: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user_id: { type: :integer },
                  timestamp: { type: :number, format: :float },
                  additions: { type: :integer, nullable: true },
                  deletions: { type: :integer, nullable: true },
                  github_url: { type: :string, nullable: true }
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
            date: { type: :string, format: :date },
            next_date: { type: :string, format: :date },
            prev_date: { type: :string, format: :date },
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      username: { type: :string },
                      display_name: { type: :string, nullable: true },
                      slack_username: { type: :string, nullable: true },
                      github_username: { type: :string, nullable: true },
                      timezone: { type: :string, nullable: true },
                      avatar_url: { type: :string, nullable: true }
                    }
                  },
                  spans: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        start_time: { type: :number, format: :float },
                        end_time: { type: :number, format: :float },
                        duration: { type: :number, format: :float },
                        files_edited: { type: :array, items: { type: :string } },
                        projects_edited_details: {
                          type: :array,
                          items: {
                            type: :object,
                            properties: {
                              name: { type: :string },
                              repo_url: { type: :string, nullable: true }
                            }
                          }
                        },
                        editors: { type: :array, items: { type: :string } },
                        languages: { type: :array, items: { type: :string } }
                      }
                    }
                  },
                  total_coded_time: { type: :number, format: :float }
                }
              }
            },
            commit_markers: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user_id: { type: :integer },
                  timestamp: { type: :number, format: :float },
                  additions: { type: :integer, nullable: true },
                  deletions: { type: :integer, nullable: true },
                  github_url: { type: :string, nullable: true }
                }
              }
            }
          }
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
                  id: { type: :integer },
                  display_name: { type: :string, nullable: true },
                  avatar_url: { type: :string, nullable: true }
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
    end
  end

  path '/api/admin/v1/timeline/leaderboard_users' do
    get('Get leaderboard users for timeline') do
      tags 'Admin Timeline'
      description 'Get users who should appear on the timeline leaderboard based on recent activity.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :period, in: :query, type: :string, enum: [ 'daily', 'last_7_days' ], description: 'Leaderboard period'

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
                  id: { type: :integer },
                  display_name: { type: :string, nullable: true },
                  avatar_url: { type: :string, nullable: true }
                }
              }
            }
          }
        run_test!
      end
    end
  end
end
