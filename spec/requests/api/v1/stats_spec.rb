require 'swagger_helper'

RSpec.describe 'Api::V1::Stats', type: :request do
  path '/api/v1/stats' do
    get('Get total coding time') do
      tags 'Stats'
      description 'Returns the total coding time for all users, optionally filtered by user or date range. Authenticated with the shared STATS_API_KEY token (Bearer header or api_key query param) — not tied to any user or admin level. Authentication is skipped entirely in development.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'text/plain'

      parameter name: :start_date, in: :query, schema: { type: :string, format: :date }, description: 'Start date (YYYY-MM-DD), defaults to 10 years ago'
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date }, description: 'End date (YYYY-MM-DD), defaults to today'
      parameter name: :username, in: :query, type: :string, description: 'Filter by username (optional)'
      parameter name: :user_email, in: :query, type: :string, description: 'Filter by user email (optional)'

      response(200, 'successful') do
        before { ENV['STATS_API_KEY'] = 'dev-api-key-12345' }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start_date) { '2023-01-01' }
        let(:end_date) { '2023-12-31' }
        let(:username) { nil }
        let(:user_email) { nil }
        schema type: :integer, example: 123456
        run_test! do |response|
          expect(response).to have_http_status(:ok)
          expect(response.body.to_i).to be >= 0
        end
      end

      response(401, 'unauthorized — Returned when STATS_API_KEY is unset/blank or the supplied token is missing or incorrect. (Auth is bypassed in the development environment.)') do
        before { ENV['STATS_API_KEY'] = 'dev-api-key-12345' }
        let(:Authorization) { "Bearer wrong-token" }
        let(:api_key) { nil }
        let(:start_date) { '2023-01-01' }
        let(:end_date) { '2023-12-31' }
        let(:username) { nil }
        let(:user_email) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(404, 'user not found') do
        before { ENV['STATS_API_KEY'] = 'dev-api-key-12345' }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start_date) { '2023-01-01' }
        let(:end_date) { '2023-12-31' }
        let(:username) { 'non_existent_user' }
        let(:user_email) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(422, 'invalid date') do
        before { ENV['STATS_API_KEY'] = 'dev-api-key-12345' }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start_date) { 'invalid-date' }
        let(:end_date) { '2023-12-31' }
        let(:username) { nil }
        let(:user_email) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/banned_users/counts' do
    get('Get newly-banned user counts') do
      tags 'Stats'
      description 'Returns the number of distinct users whose trust level was newly set to "red" (banned/convicted) over the last day, week, and month.'
      produces 'application/json'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            day: { type: :integer, example: 3 },
            week: { type: :integer, example: 12 },
            month: { type: :integer, example: 48 }
          },
          required: %w[day week month]
        run_test! do |response|
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body).to include('day', 'week', 'month')
        end
      end
    end
  end

  path '/api/v1/users/{username}/heartbeats/spans' do
    get('Get user heartbeat spans') do
      tags 'Stats'
      description 'Returns heartbeat spans for a user, useful for visualizations. Accessible anonymously when the target user has public stats lookup enabled; otherwise the requester must be the user (authenticated via the User API Key).'
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username, Slack ID, or User ID. The literal value "my" resolves the user from the Authorization Bearer token.'
      parameter name: :start_date, in: :query, schema: { type: :string, format: :date_time }, description: 'Start date/time (ISO 8601), defaults to 10 years ago'
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date_time }, description: 'End date/time (ISO 8601), defaults to end of today'
      parameter name: :project, in: :query, type: :string, description: 'Filter by single project'
      parameter name: :filter_by_project, in: :query, type: :string, description: 'Filter by multiple projects (comma separated). Ignored if project is present.'

      response(200, 'successful') do
        let(:username) { 'testuser' }
        let(:start_date) { '2023-01-01' }
        let(:end_date) { '2023-01-02' }
        let(:project) { nil }
        let(:filter_by_project) { nil }

        schema type: :object,
          properties: {
            spans: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  start_time: { type: :number, description: 'Span start time (epoch seconds)', example: 1717689600.0 },
                  end_time: { type: :number, description: 'Span end time (epoch seconds)', example: 1717691820.5 },
                  duration: { type: :number, description: 'Span duration (seconds)', example: 2220.5 }
                }
              }
            }
          }
        run_test!
      end

      response(403, 'forbidden — The target user has disabled public stats lookup and the requester is not that user.') do
        before do
          user = User.create!(username: 'private_spans_user', slack_uid: 'PRIVATE_SPANS_1', allow_public_stats_lookup: false, timezone: 'America/New_York')
          user.email_addresses.create!(email: 'private_spans@example.com')
        end
        let(:username) { 'private_spans_user' }
        let(:start_date) { '2023-01-01' }
        let(:end_date) { '2023-01-02' }
        let(:project) { nil }
        let(:filter_by_project) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(404, 'user not found') do
        let(:username) { 'non_existent_user' }
        let(:start_date) { '2023-01-01' }
        let(:end_date) { '2023-01-02' }
        let(:project) { nil }
        let(:filter_by_project) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(422, 'invalid date') do
        let(:username) { 'testuser' }
        let(:start_date) { 'invalid-date' }
        let(:end_date) { '2023-01-02' }
        let(:project) { nil }
        let(:filter_by_project) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/users/{username}/trust_factor' do
    get('Get user trust factor') do
      tags 'Stats'
      description 'Returns the (masked) trust level and value for a user. Only the public-facing levels are ever returned: blue (0, unscored), red (1, convicted), green (2, trusted). The internal "yellow" (suspected) level is masked to blue and never exposed.'
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username, Slack ID, or User ID'

      response(200, 'successful') do
        let(:username) { 'testuser' }

        schema type: :object,
          properties: {
            trust_level: { type: :string, enum: %w[blue red green], example: 'blue' },
            trust_value: { type: :integer, enum: [ 0, 1, 2 ], example: 0 }
          }
        run_test!
      end

      response(404, 'not found') do
        let(:username) { 'unknown_user' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/users/{username}/projects' do
    get('Get user project names') do
      tags 'Stats'
      description 'Returns a list of project names for a user from the last 30 days. Accessible anonymously when the target user has public stats lookup enabled.'
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username, Slack ID, or User ID'

      response(200, 'successful') do
        let(:username) { 'testuser' }

        schema type: :object,
          properties: {
            projects: {
              type: :array,
              items: { type: :string, example: 'hackatime' }
            }
          }
        run_test!
      end

      response(403, 'forbidden — The target user has disabled public stats lookup and the requester is not that user.') do
        before do
          user = User.create!(username: 'private_projects_user', slack_uid: 'PRIVATE_PROJ_1', allow_public_stats_lookup: false, timezone: 'America/New_York')
          user.email_addresses.create!(email: 'private_projects@example.com')
        end
        let(:username) { 'private_projects_user' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(404, 'not found') do
        let(:username) { 'unknown_user' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/users/{username}/project/{project_name}' do
    get('Get user project details') do
      tags 'Stats'
      description 'Returns details for a specific project. Accessible anonymously when the target user has public stats lookup enabled.'
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username, Slack ID, or User ID'
      parameter name: :project_name, in: :path, type: :string, description: 'Project name'
      parameter name: :start, in: :query, schema: { type: :string, format: :date_time }
      parameter name: :end, in: :query, schema: { type: :string, format: :date_time }
      parameter name: :start_date, in: :query, schema: { type: :string, format: :date_time }
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date_time }

      response(200, 'successful') do
        let(:username) { 'testuser' }
        let(:project_name) { 'harbor' }
        let(:start) { nil }
        let(:end) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }

        schema type: :object,
          properties: {
            name: { type: :string, example: 'hackatime' },
            total_seconds: { type: :number, example: 14820.5 },
            languages: { type: :array, items: { type: :string, example: 'Ruby' }, example: %w[Ruby Svelte TypeScript] },
            repo_url: { type: :string, nullable: true, example: 'https://github.com/hackclub/hackatime' },
            total_heartbeats: { type: :integer, example: 482 },
            first_heartbeat: { type: :string, format: :date_time, nullable: true, example: '2024-03-20T15:30:00Z' },
            last_heartbeat: { type: :string, format: :date_time, nullable: true, example: '2024-06-06T18:45:00Z' },
            most_recent_heartbeat: { type: :string, format: :date_time, nullable: true, example: '2024-06-06T18:45:00Z' },
            archived: { type: :boolean, example: false }
          }
        run_test!
      end

      response(400, 'bad request — Returned when project_name is blank/whitespace-only.') do
        let(:username) { 'testuser' }
        let(:project_name) { '%20' }
        let(:start) { nil }
        let(:end) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(403, 'forbidden — The target user has disabled public stats lookup and the requester is not that user.') do
        before do
          user = User.create!(username: 'private_project_user', slack_uid: 'PRIVATE_PROJ_2', allow_public_stats_lookup: false, timezone: 'America/New_York')
          user.email_addresses.create!(email: 'private_project@example.com')
        end
        let(:username) { 'private_project_user' }
        let(:project_name) { 'harbor' }
        let(:start) { nil }
        let(:end) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(404, 'not found — Returned when the user is not found, or no data exists for the requested project.') do
        let(:username) { 'non_existent_user' }
        let(:project_name) { 'harbor' }
        let(:start) { nil }
        let(:end) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/users/{username}/projects/details' do
    get('Get details for multiple projects') do
      tags 'Stats'
      description 'Returns details for multiple projects, or all projects in a time range. Accessible anonymously when the target user has public stats lookup enabled.'
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username, Slack ID, or User ID'
      parameter name: :projects, in: :query, type: :string, description: 'Comma-separated project names'
      parameter name: :since, in: :query, schema: { type: :string, format: :date_time }, description: 'Start time (ISO 8601) for project discovery'
      parameter name: :until, in: :query, schema: { type: :string, format: :date_time }, description: 'End time (ISO 8601) for project discovery'
      parameter name: :until_date, in: :query, schema: { type: :string, format: :date_time }, description: 'End time (ISO 8601) for project discovery'
      parameter name: :start, in: :query, schema: { type: :string, format: :date_time }
      parameter name: :end, in: :query, schema: { type: :string, format: :date_time }
      parameter name: :start_date, in: :query, schema: { type: :string, format: :date_time }
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date_time }

      response(200, 'successful') do
        let(:username) { 'testuser' }
        let(:projects) { nil }
        let(:since) { nil }
        let(:until) { nil }
        let(:until_date) { nil }
        let(:start) { nil }
        let(:end) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }

        schema type: :object,
          properties: {
            projects: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  name: { type: :string, example: 'hackatime' },
                  total_seconds: { type: :number, example: 14820.5 },
                  languages: { type: :array, items: { type: :string, example: 'Ruby' }, example: %w[Ruby Svelte TypeScript] },
                  repo_url: { type: :string, nullable: true, example: 'https://github.com/hackclub/hackatime' },
                  total_heartbeats: { type: :integer, example: 482 },
                  first_heartbeat: { type: :string, format: :date_time, nullable: true, example: '2024-03-20T15:30:00Z' },
                  last_heartbeat: { type: :string, format: :date_time, nullable: true, example: '2024-06-06T18:45:00Z' },
                  most_recent_heartbeat: { type: :string, format: :date_time, nullable: true, example: '2024-06-06T18:45:00Z' },
                  archived: { type: :boolean, example: false }
                }
              }
            }
          }
        run_test!
      end

      response(403, 'forbidden — The target user has disabled public stats lookup and the requester is not that user.') do
        before do
          user = User.create!(username: 'private_details_user', slack_uid: 'PRIVATE_DET_1', allow_public_stats_lookup: false, timezone: 'America/New_York')
          user.email_addresses.create!(email: 'private_details@example.com')
        end
        let(:username) { 'private_details_user' }
        let(:projects) { nil }
        let(:since) { nil }
        let(:until) { nil }
        let(:until_date) { nil }
        let(:start) { nil }
        let(:end) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(404, 'user not found') do
        let(:username) { 'non_existent_user' }
        let(:projects) { nil }
        let(:since) { nil }
        let(:until) { nil }
        let(:until_date) { nil }
        let(:start) { nil }
        let(:end) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/users/{username}/stats' do
    get('Get user stats') do
      tags 'Stats'
      description <<~DESC.strip
        Returns detailed coding stats for a specific user, including languages, projects, and total time.

        Authentication is OPTIONAL: the endpoint is publicly accessible (no token) whenever the target user has public stats lookup enabled. When a User API Key is supplied it is used to resolve the special username "my" and to grant access to the caller's own private stats.

        When total_seconds=true, the response shape is instead { "total_seconds": <number> }.
      DESC
      security [ {}, { Bearer: [] }, { ApiKeyAuth: [] } ]
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username, Slack ID, or User ID. The literal value "my" resolves the current user from the Authorization Bearer token (User API Key).'
      parameter name: :start_date, in: :query, schema: { type: :string, format: :date_time }, description: 'Start date/time (ISO 8601), defaults to 10 years ago'
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date_time }, description: 'End date/time (ISO 8601), defaults to end of today'
      parameter name: :limit, in: :query, type: :integer, description: 'Limit number of results'
      parameter name: :features, in: :query, type: :string, description: 'Comma-separated list of features to include (e.g., languages,projects). Defaults to languages.'
      parameter name: :filter_by_project, in: :query, type: :string, description: 'Filter results by specific project names (comma-separated)'
      parameter name: :filter_by_category, in: :query, type: :string, description: 'Filter results by category (comma-separated)'
      parameter name: :boundary_aware, in: :query, type: :boolean, description: 'Use boundary aware calculation (only applied in the total_seconds branch)'
      parameter name: :total_seconds, in: :query, type: :boolean, description: 'When "true", returns only { total_seconds: <number> } instead of the full stats object'
      parameter name: :no_ai_coding, in: :query, type: :boolean, description: 'When "true", excludes the "ai coding" category from totals/summary. Caveat: heartbeats with no category at all (legacy data) are also excluded due to SQL NULL-comparison semantics.'
      parameter name: :test_param, in: :query, type: :boolean, description: 'When "true", switches to test mode: forces boundary-aware + valid-timestamps-only and excludes the browsing/meeting/communicating categories (plus "ai coding" when no_ai_coding=true)'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:username) { 'testuser' }
        let(:start_date) { '2023-01-01' }
        let(:end_date) { '2023-12-31' }
        let(:limit) { nil }
        let(:features) { nil }
        let(:filter_by_project) { nil }
        let(:filter_by_category) { nil }
        let(:boundary_aware) { nil }
        let(:total_seconds) { nil }
        let(:no_ai_coding) { nil }
        let(:test_param) { nil }
        schema type: :object,
          properties: {
            data: {
              allOf: [
                { '$ref' => '#/components/schemas/StatsSummary' },
                {
                  type: :object,
                  properties: {
                    unique_total_seconds: {
                      type: :number,
                      description: 'Only present when features includes "projects" AND filter_by_project is supplied.',
                      example: 12960.0
                    }
                  }
                }
              ]
            },
            trust_factor: {
              type: :object,
              properties: {
                trust_level: { type: :string, enum: %w[blue red green], example: 'blue' },
                trust_value: { type: :integer, enum: [ 0, 1, 2 ], example: 0 }
              }
            }
          }
        run_test!
      end

      response(403, 'forbidden — User has disabled public stats lookup') do
        before do
          user = User.create!(username: 'private_user', slack_uid: 'PRIVATE_123', allow_public_stats_lookup: false, timezone: 'America/New_York')
          user.email_addresses.create!(email: 'private@example.com')
        end
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:username) { 'private_user' }
        let(:start_date) { '2023-01-01' }
        let(:end_date) { '2023-12-31' }
        let(:limit) { nil }
        let(:features) { nil }
        let(:filter_by_project) { nil }
        let(:filter_by_category) { nil }
        let(:boundary_aware) { nil }
        let(:total_seconds) { nil }
        let(:no_ai_coding) { nil }
        let(:test_param) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:username) { 'non_existent_user' }
        let(:start_date) { '2023-01-01' }
        let(:end_date) { '2023-12-31' }
        let(:limit) { nil }
        let(:features) { nil }
        let(:filter_by_project) { nil }
        let(:filter_by_category) { nil }
        let(:boundary_aware) { nil }
        let(:total_seconds) { nil }
        let(:no_ai_coding) { nil }
        let(:test_param) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end

      response(422, 'invalid date') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:username) { 'testuser' }
        let(:start_date) { 'invalid-date' }
        let(:end_date) { '2023-12-31' }
        let(:limit) { nil }
        let(:features) { nil }
        let(:filter_by_project) { nil }
        let(:filter_by_category) { nil }
        let(:boundary_aware) { nil }
        let(:total_seconds) { nil }
        let(:no_ai_coding) { nil }
        let(:test_param) { nil }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
