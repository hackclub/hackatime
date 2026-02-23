require 'swagger_helper'

RSpec.describe 'Api::V1::Authenticated', type: :request do
  path '/api/v1/authenticated/me' do
    get('Get current user info') do
      tags 'Authenticated'
      description 'Returns detailed information about the currently authenticated user.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        schema type: :object,
          properties: {
            id: { type: :integer },
            emails: { type: :array, items: { type: :string } },
            slack_id: { type: :string, nullable: true },
            github_username: { type: :string, nullable: true },
            trust_factor: {
              type: :object,
              properties: {
                trust_level: { type: :string },
                trust_value: { type: :integer }
              }
            }
          }
        run_test! do |response|
          expect(response).to have_http_status(:ok)
          body = JSON.parse(response.body)
          expect(body).to include("id", "emails", "trust_factor")
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { "invalid" }
        # schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/hours' do
    get('Get hours') do
      tags 'Authenticated'
      description 'Returns the total coding hours for the authenticated user.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :start_date, in: :query, schema: { type: :string, format: :date }, description: 'Start date (YYYY-MM-DD)'
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date }, description: 'End date (YYYY-MM-DD)'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
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

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { "invalid" }
        let(:start_date) { 7.days.ago.to_date.to_s }
        let(:end_date) { Date.today.to_s }
        # schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/streak' do
    get('Get streak') do
      tags 'Authenticated'
      description 'Returns the current streak information (days coded in a row).'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        schema type: :object,
          properties: {
            streak_days: { type: :integer, example: 5 }
          }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { "invalid" }
        let(:start_date) { 7.days.ago.to_date.to_s }
        let(:end_date) { Date.today.to_s }
        # schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/projects' do
    get('Get projects') do
      tags 'Authenticated'
      description 'Returns a list of projects associated with the authenticated user.'
      security [ Bearer: [], ApiKeyAuth: [] ]
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
        let(:api_key) { "dev-api-key-12345" }
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
                  most_recent_heartbeat: { type: :string, format: :date_time, nullable: true },
                  languages: { type: :array, items: { type: :string } },
                  archived: { type: :boolean }
                }
              }
            }
          }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { "invalid" }
        let(:include_archived) { false }
        let(:projects) { nil }
        let(:since) { nil }
        let(:until) { nil }
        let(:until_date) { nil }
        let(:start) { nil }
        let(:end) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        # schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/api_keys' do
    get('Get API keys') do
      tags 'Authenticated'
      description 'Returns the API keys for the authenticated user. Warning: This returns sensitive information.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        schema type: :object,
          properties: {
            token: { type: :string, example: 'waka_...' }
          }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { "invalid" }
        # schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/heartbeats/latest' do
    get('Get latest heartbeat') do
      tags 'Authenticated'
      description 'Returns the absolutely latest heartbeat processed for the user.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        schema type: :object,
          properties: {
            id: { type: :integer },
            created_at: { type: :string, format: :date_time },
            time: { type: :number },
            category: { type: :string },
            project: { type: :string },
            language: { type: :string },
            editor: { type: :string },
            operating_system: { type: :string },
            machine: { type: :string },
            entity: { type: :string }
          }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { "invalid" }
        # schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
