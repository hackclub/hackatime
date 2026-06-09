require 'swagger_helper'

RSpec.describe 'Api::V1::Authenticated', type: :request do
  path '/api/v1/authenticated/me' do
    get('Get current user info') do
      tags 'OAuth2-specific'
      description 'Returns detailed information about the currently authenticated user. Requires an OAuth2 access token (Bearer header).'
      security [ { Bearer: [] } ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        schema type: :object,
          properties: {
            id: { type: :integer, example: 42 },
            emails: { type: :array, items: { type: :string, example: 'orpheus@hackclub.com' } },
            slack_id: { type: :string, nullable: true, example: 'U0266FRGP' },
            github_username: { type: :string, nullable: true, example: 'orpheus' },
            trust_factor: {
              type: :object,
              properties: {
                trust_level: { type: :string, example: 'blue' },
                trust_value: { type: :integer, example: 0 }
              }
            }
          }
        run_test! do |response|
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body).to include("id", "emails", "trust_factor")
        end
      end

      response(401, 'unauthorized — Returned when the OAuth access token is missing or invalid.') do
        let(:Authorization) { 'Bearer invalid' }
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/hours' do
    get('Get hours') do
      tags 'OAuth2-specific'
      description 'Returns the total coding hours for the authenticated user. Requires an OAuth2 access token (Bearer header).'
      security [ { Bearer: [] } ]
      produces 'application/json'

      parameter name: :start_date, in: :query, schema: { type: :string, format: :date }, description: 'Start date (YYYY-MM-DD)'
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date }, description: 'End date (YYYY-MM-DD)'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:start_date) { 7.days.ago.to_date.to_s }
        let(:end_date) { Date.today.to_s }
        schema type: :object,
          properties: {
            start_date: { type: :string, format: :date, example: '2024-03-13' },
            end_date: { type: :string, format: :date, example: '2024-03-20' },
            total_seconds: { type: :number, example: 153000.0 }
          }
        run_test!
      end

      response(401, 'unauthorized — Returned when the OAuth access token is missing or invalid (empty body), or when the authenticated user is banned (`trust_level == "red"`) via the `ensure_no_ban` before_action (which responds with a `{ "error": "Unauthorized" }` body).') do
        let(:Authorization) { 'Bearer invalid' }
        let(:start_date) { 7.days.ago.to_date.to_s }
        let(:end_date) { Date.today.to_s }
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/streak' do
    get('Get streak') do
      tags 'OAuth2-specific'
      description 'Returns the current streak information (days coded in a row). Requires an OAuth2 access token (Bearer header).'
      security [ { Bearer: [] } ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        schema type: :object,
          properties: {
            streak_days: { type: :integer, example: 5 }
          }
        run_test!
      end

      response(401, 'unauthorized — Returned when the OAuth access token is missing or invalid.') do
        let(:Authorization) { 'Bearer invalid' }
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/projects' do
    get('Get projects') do
      tags 'OAuth2-specific'
      description 'Returns a list of projects associated with the authenticated user. Requires an OAuth2 access token (Bearer header).'
      security [ { Bearer: [] } ]
      produces 'application/json'

      parameter name: :include_archived, in: :query, type: :boolean, description: 'Include archived projects (true/false)'
      parameter name: :projects, in: :query, type: :string, description: 'Comma-separated list of project names'
      parameter name: :since, in: :query, schema: { type: :string, format: :date_time }, description: 'Project discovery start time (ISO 8601)'
      parameter name: :until, in: :query, schema: { type: :string, format: :date_time }, description: 'Project discovery end time (ISO 8601)'
      parameter name: :until_date, in: :query, schema: { type: :string, format: :date_time }, description: 'Alias for until'
      parameter name: :start, in: :query, schema: { type: :string, format: :date_time }, description: 'Stats start time (ISO 8601)'
      parameter name: :end, in: :query, schema: { type: :string, format: :date_time }, description: 'Stats end time (ISO 8601)'
      parameter name: :start_date, in: :query, schema: { type: :string, format: :date_time }, description: 'Alias for start'
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date_time }, description: 'Alias for end'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:include_archived) { false }
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
                  total_seconds: { type: :number, example: 3600.0 },
                  most_recent_heartbeat: { type: :string, format: :date_time, nullable: true, example: '2024-03-20T15:30:00Z' },
                  languages: { type: :array, items: { type: :string, example: 'Ruby' } },
                  archived: { type: :boolean, example: false }
                }
              }
            }
          }
        run_test!
      end

      response(401, 'unauthorized — Returned when the OAuth access token is missing or invalid.') do
        let(:Authorization) { 'Bearer invalid' }
        let(:include_archived) { false }
        let(:projects) { nil }
        let(:since) { nil }
        let(:until) { nil }
        let(:until_date) { nil }
        let(:start) { nil }
        let(:end) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/api_keys' do
    get('Get API keys') do
      tags 'OAuth2-specific'
      description 'Returns the API keys for the authenticated user. Requires an OAuth2 access token (Bearer header). Warning: This returns sensitive information.'
      security [ { Bearer: [] } ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        schema type: :object,
          properties: {
            token: { type: :string, example: '550e8400-e29b-41d4-a716-446655440000' }
          }
        run_test!
      end

      response(401, 'unauthorized — Returned when the OAuth access token is missing or invalid.') do
        let(:Authorization) { 'Bearer invalid' }
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/heartbeats/latest' do
    get('Get latest heartbeat') do
      tags 'OAuth2-specific'
      description 'Returns the absolutely latest heartbeat processed for the user. Requires an OAuth2 access token (Bearer header). ' \
                  'When the user has no non-test heartbeat, the response is `{ "heartbeat": null }`.'
      security [ { Bearer: [] } ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        schema oneOf: [
          {
            type: :object,
            title: 'Latest heartbeat',
            properties: {
              id: { type: :integer, example: 987654 },
              created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
              time: { type: :number, example: 1710948600.0 },
              category: { type: :string, example: 'coding' },
              project: { type: :string, example: 'hackatime' },
              language: { type: :string, example: 'Ruby' },
              editor: { type: :string, example: 'VS Code' },
              operating_system: { type: :string, example: 'Mac' },
              machine: { type: :string, example: 'Orpheus-MacBook-Pro' },
              entity: { type: :string, example: 'app/models/user.rb' }
            },
            required: %w[id time]
          },
          {
            type: :object,
            title: 'No heartbeats yet',
            description: 'Returned when the user has no non-test heartbeat.',
            properties: {
              heartbeat: { type: :object, nullable: true, example: nil }
            },
            required: %w[heartbeat]
          }
        ]
        run_test!
      end

      response(401, 'unauthorized — Returned when the OAuth access token is missing or invalid.') do
        let(:Authorization) { 'Bearer invalid' }
        run_test!
      end
    end
  end
end
