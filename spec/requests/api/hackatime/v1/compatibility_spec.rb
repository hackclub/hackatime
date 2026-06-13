require 'swagger_helper'

RSpec.describe 'Api::Hackatime::V1::Compatibility', type: :request do
  path '/api/hackatime/v1/users/{id}/heartbeats' do
    post('Push heartbeats (WakaTime compatible)') do
      tags 'WakaTime Compatibility'
      description 'Endpoint used by WakaTime plugins to send heartbeat data to the server. This is the core endpoint for tracking time.'
      consumes 'application/json'
      security [ Bearer: [], ApiKeyAuth: [] ]

      parameter name: :id, in: :path, type: :string, description: 'User ID or "current" (recommended). The authenticated user is resolved from the API token, not this path segment.'
      parameter name: :heartbeats, in: :body, schema: {
        type: :array,
        description: 'Array of heartbeats. The single (non-bulk) variant only processes the first element of the array.',
        items: {
          type: :object,
          properties: {
            entity: { type: :string, example: 'app/models/user.rb', description: 'File path or entity being tracked' },
            type: { type: :string, example: 'file', description: 'Entity type, e.g. "file"' },
            time: { type: :number, example: 1710946200.0, description: 'Unix timestamp (seconds, float)' },
            project: { type: :string, example: 'hackatime' },
            branch: { type: :string, example: 'main' },
            language: { type: :string, example: 'Ruby' },
            is_write: { type: :boolean, example: true },
            lineno: { type: :integer, example: 42 },
            cursorpos: { type: :integer, example: 12 },
            lines: { type: :integer, example: 350 },
            category: { type: :string, example: 'coding' },
            created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
            dependencies: { type: :array, items: { type: :string, example: 'rails' }, description: 'May also be sent as a string' },
            editor: { type: :string, example: 'VS Code' },
            line_additions: { type: :integer, example: 8 },
            line_deletions: { type: :integer, example: 3 },
            machine: { type: :string, example: 'Orpheus-MacBook-Pro' },
            operating_system: { type: :string, example: 'Mac' },
            project_root_count: { type: :integer, example: 4 },
            user_agent: { type: :string, example: 'wakatime/v1.115.2 (darwin-24.6.0) go1.23 vscode/1.96.0' },
            plugin: { type: :string, example: 'vscode/1.96.0 vscode-wakatime/24.6.0', description: 'Accepted but not persisted' }
          }
        }
      }

      response(202, 'accepted') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:id) { 'current' }
        let(:heartbeats) { [ { entity: 'file.rb', time: Time.now.to_f } ] }
        schema type: :object,
          description: 'The created heartbeat (the .attributes hash of the first accepted heartbeat).',
          properties: {
            id: { type: :integer, example: 987654 },
            entity: { type: :string, nullable: true, example: 'app/models/user.rb' },
            type: { type: :string, nullable: true, example: 'file' },
            time: { type: :number, example: 1710946200.0 },
            project: { type: :string, nullable: true, example: 'hackatime' },
            branch: { type: :string, nullable: true, example: 'main' },
            language: { type: :string, nullable: true, example: 'Ruby' },
            is_write: { type: :boolean, nullable: true, example: true },
            lineno: { type: :integer, nullable: true, example: 42 },
            cursorpos: { type: :integer, nullable: true, example: 12 },
            lines: { type: :integer, nullable: true, example: 350 },
            category: { type: :string, example: 'coding' },
            created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
            user_id: { type: :integer, example: 42 },
            editor: { type: :string, nullable: true, example: 'VS Code' },
            operating_system: { type: :string, nullable: true, example: 'Mac' },
            machine: { type: :string, nullable: true, example: 'Orpheus-MacBook-Pro' },
            user_agent: { type: :string, nullable: true, example: 'wakatime/v1.115.2 (darwin-24.6.0) go1.23 vscode/1.96.0' }
          }
        run_test!
      end

      response(400, 'no data provided') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:id) { 'current' }
        let(:heartbeats) { [] }
        schema type: :object, properties: { error: { type: :string, example: 'No data provided...' } }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { 'invalid' }
        let(:id) { 'current' }
        let(:heartbeats) { [] }
        run_test!
      end

      response(403, 'account pending deletion') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:id) { 'current' }
        let(:heartbeats) { [ { entity: 'file.rb', time: Time.now.to_f } ] }
        before do
          user = ApiKey.find_by(token: 'dev-api-key-12345').user
          DeletionRequest.create!(user: user, requested_at: Time.current, status: :pending, reason: nil, reason_details: nil)
        end
        schema type: :object, properties: { error: { type: :string, example: 'Account pending deletion' } }
        run_test!
      end

      response(429, 'rate limit exceeded') do
        schema type: :object,
          properties: {
            error: { type: :string, example: 'Rate limit exceeded' },
            message: { type: :string, example: 'You have exceeded the heartbeat upload rate limit. Please try again later.' },
            retry_after: { type: :integer, example: 30 },
            reset_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:30Z' }
          }
        header 'Retry-After', schema: { type: :string, example: '30' }, description: 'Seconds until the rate limit resets'
        header 'X-RateLimit-Limit', schema: { type: :string, example: '360' }
        header 'X-RateLimit-Remaining', schema: { type: :string, example: '0' }
        header 'X-RateLimit-Reset', schema: { type: :string, example: '30' }
        header 'X-RateLimit-Reset-At', schema: { type: :string, example: '2024-03-20T15:30:30Z' }
      end
    end
  end

  path '/api/hackatime/v1/users/{id}/heartbeats.bulk' do
    post('Push heartbeats in bulk (WakaTime compatible)') do
      tags 'WakaTime Compatibility'
      description 'Bulk variant of the heartbeat ingest endpoint, used by WakaTime clients via the ".bulk" format extension. ' \
                  'Resolves to the same controller action (push_heartbeats) which detects params["format"] == "bulk". ' \
                  'Accepts up to 100 heartbeats per request and returns a per-heartbeat array of [attributes_or_error, status_code] pairs.'
      consumes 'application/json'
      security [ Bearer: [], ApiKeyAuth: [] ]

      parameter name: :id, in: :path, type: :string, description: 'User ID or "current" (recommended). The authenticated user is resolved from the API token, not this path segment.'
      parameter name: :heartbeats, in: :body, schema: {
        type: :array,
        description: 'Array of heartbeats (max 100). May be sent as a top-level JSON array, a text/plain JSON array, or wrapped as { hackatime: { heartbeats: [...] } }.',
        items: {
          type: :object,
          properties: {
            entity: { type: :string, example: 'app/models/user.rb' },
            type: { type: :string, example: 'file' },
            time: { type: :number, example: 1710946200.0 },
            project: { type: :string, example: 'hackatime' },
            branch: { type: :string, example: 'main' },
            language: { type: :string, example: 'Ruby' },
            is_write: { type: :boolean, example: true },
            lineno: { type: :integer, example: 42 },
            cursorpos: { type: :integer, example: 12 },
            lines: { type: :integer, example: 350 },
            category: { type: :string, example: 'coding' },
            created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
            dependencies: { type: :array, items: { type: :string, example: 'rails' } },
            editor: { type: :string, example: 'VS Code' },
            line_additions: { type: :integer, example: 8 },
            line_deletions: { type: :integer, example: 3 },
            machine: { type: :string, example: 'Orpheus-MacBook-Pro' },
            operating_system: { type: :string, example: 'Mac' },
            project_root_count: { type: :integer, example: 4 },
            user_agent: { type: :string, example: 'wakatime/v1.115.2 (darwin-24.6.0) go1.23 vscode/1.96.0' },
            plugin: { type: :string, example: 'vscode/1.96.0 vscode-wakatime/24.6.0' }
          }
        }
      }

      response(201, 'created') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:id) { 'current' }
        let(:heartbeats) { [ { entity: 'file.rb', time: Time.now.to_f } ] }
        schema type: :object,
          description: 'Per-heartbeat responses. Each item is a [body, status_code] pair: [attributes, 201] for accepted heartbeats or [{ error, type }, 422] for failures.',
          properties: {
            responses: {
              type: :array,
              items: {
                type: :array,
                description: 'Tuple of [heartbeat attributes or error object, HTTP status code]'
              }
            }
          }
        run_test!
      end

      response(400, 'no data or too many heartbeats') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:id) { 'current' }
        let(:heartbeats) { Array.new(101) { { entity: 'file.rb', time: Time.now.to_f } } }
        schema type: :object, properties: { error: { type: :string, example: 'Too many heartbeats in a single request (max 100)' } }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { 'invalid' }
        let(:id) { 'current' }
        let(:heartbeats) { [ { entity: 'file.rb', time: Time.now.to_f } ] }
        run_test!
      end
    end
  end

  path '/api/hackatime/v1/users/{id}/statusbar/today' do
    get('Get status bar today') do
      tags 'WakaTime Compatibility'
      description 'Returns the total coding time for today. Used by editor plugins to display the status bar widget.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :id, in: :path, type: :string, description: 'User ID or "current"'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:id) { 'current' }
        schema type: :object,
          properties: {
            data: {
              type: :object,
              properties: {
                grand_total: {
                  type: :object,
                  properties: {
                    total_seconds: { type: :number, example: 7200.0 },
                    text: { type: :string, example: '2h 30m / 4h goal' }
                  }
                },
                goal: {
                  type: :object,
                  nullable: true,
                  properties: {
                    target_seconds: { type: :number, example: 14400 },
                    tracked_seconds: { type: :number, example: 9000 },
                    completion_percent: { type: :number, example: 62 },
                    complete: { type: :boolean, example: false }
                  }
                }
              }
            }
          }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { 'invalid' }
        let(:id) { 'current' }
        run_test!
      end
    end
  end

  path '/api/hackatime/v1/users/current/stats/last_7_days' do
      get('Get last 7 days stats') do
        tags 'WakaTime Compatibility'
        description 'Returns coding statistics for the last 7 days. Used by some WakaTime dashboards.'
        security [ Bearer: [], ApiKeyAuth: [] ]
        produces 'application/json'

        response(200, 'successful') do
          let(:Authorization) { "Bearer dev-api-key-12345" }
          let(:api_key) { "dev-api-key-12345" }
          schema type: :object,
            properties: {
              data: {
                type: :object,
                properties: {
                  username: { type: :string, example: 'U0266FRGP' },
                  user_id: { type: :string, example: 'U0266FRGP' },
                  start: { type: :string, format: :date_time, example: '2024-03-13T00:00:00Z' },
                  end: { type: :string, format: :date_time, example: '2024-03-20T23:59:59Z' },
                  status: { type: :string, example: 'ok' },
                  total_seconds: { type: :number, example: 25200 },
                  daily_average: { type: :number, example: 3600.0 },
                  days_including_holidays: { type: :integer, example: 7 },
                  range: { type: :string, example: 'last_7_days' },
                  human_readable_range: { type: :string, example: 'Last 7 Days' },
                  human_readable_total: { type: :string, example: '7 hrs 0 mins' },
                  human_readable_daily_average: { type: :string, example: '1 hrs 0 mins' },
                  is_coding_activity_visible: { type: :boolean, example: true },
                  is_other_usage_visible: { type: :boolean, example: true },
                  editors: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string, example: 'VS Code' },
                        total_seconds: { type: :integer, example: 25200 },
                        percent: { type: :number, example: 100.0 },
                        digital: { type: :string, example: '7:00:00' },
                        text: { type: :string, example: '7 hrs 0 mins' },
                        hours: { type: :integer, example: 7 },
                        minutes: { type: :integer, example: 0 },
                        seconds: { type: :integer, example: 0 }
                      }
                    }
                  },
                  languages: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string, example: 'Ruby' },
                        total_seconds: { type: :integer, example: 18000 },
                        percent: { type: :number, example: 71.43 },
                        digital: { type: :string, example: '5:00:00' },
                        text: { type: :string, example: '5 hrs 0 mins' },
                        hours: { type: :integer, example: 5 },
                        minutes: { type: :integer, example: 0 },
                        seconds: { type: :integer, example: 0 }
                      }
                    }
                  },
                  machines: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string, example: 'Orpheus-MacBook-Pro' },
                        total_seconds: { type: :integer, example: 25200 },
                        percent: { type: :number, example: 100.0 },
                        digital: { type: :string, example: '7:00:00' },
                        text: { type: :string, example: '7 hrs 0 mins' },
                        hours: { type: :integer, example: 7 },
                        minutes: { type: :integer, example: 0 },
                        seconds: { type: :integer, example: 0 }
                      }
                    }
                  },
                  projects: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string, example: 'hackatime' },
                        total_seconds: { type: :integer, example: 21600 },
                        percent: { type: :number, example: 85.71 },
                        digital: { type: :string, example: '6:00:00' },
                        text: { type: :string, example: '6 hrs 0 mins' },
                        hours: { type: :integer, example: 6 },
                        minutes: { type: :integer, example: 0 },
                        seconds: { type: :integer, example: 0 }
                      }
                    }
                  },
                  operating_systems: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string, example: 'Mac' },
                        total_seconds: { type: :integer, example: 25200 },
                        percent: { type: :number, example: 100.0 },
                        digital: { type: :string, example: '7:00:00' },
                        text: { type: :string, example: '7 hrs 0 mins' },
                        hours: { type: :integer, example: 7 },
                        minutes: { type: :integer, example: 0 },
                        seconds: { type: :integer, example: 0 }
                      }
                    }
                  },
                  categories: {
                    type: :array,
                    items: {
                      type: :object,
                      properties: {
                        name: { type: :string, example: 'coding' },
                        total_seconds: { type: :integer, example: 25200 },
                        percent: { type: :number, example: 100.0 },
                        digital: { type: :string, example: '7:00:00' },
                        text: { type: :string, example: '7 hrs 0 mins' },
                        hours: { type: :integer, example: 7 },
                        minutes: { type: :integer, example: 0 },
                        seconds: { type: :integer, example: 0 }
                      }
                    }
                  }
                }
              }
            }
          run_test!
        end

        response(401, 'unauthorized') do
          let(:Authorization) { 'Bearer invalid' }
          let(:api_key) { 'invalid' }
          run_test!
        end
      end
    end
end
