require 'swagger_helper'

RSpec.describe 'Api::V1::Users', type: :request do
  path '/api/v1/users/lookup_email/{email}' do
    get('Lookup user by email') do
      tags 'Users'
      description 'Find a user ID by their email address. Useful for integrations that need to map emails to Hackatime users. Requires STATS_API_KEY.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :email, in: :path, type: :string, description: 'Email address to lookup'

      response(200, 'successful') do
        before { ENV['STATS_API_KEY'] = 'dev-api-key-12345' }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:email) { 'test@example.com' }
        schema type: :object,
          properties: {
            user_id: { type: :integer, example: 42 },
            email: { type: :string, example: 'test@example.com' }
          }
        run_test!
      end

      response(404, 'not found') do
        before { ENV['STATS_API_KEY'] = 'dev-api-key-12345' }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:email) { 'unknown@example.com' }
        schema type: :object,
          properties: {
            error: { type: :string, example: 'User not found' },
            email: { type: :string, example: 'unknown@example.com' }
          }
        run_test!
      end
    end
  end

  path '/api/v1/users/lookup_slack_uid/{slack_uid}' do
    get('Lookup user by Slack UID') do
      tags 'Users'
      description 'Find a user ID by their Slack User ID. Requires STATS_API_KEY.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :slack_uid, in: :path, type: :string, description: 'Slack User ID (e.g. U123456)'

      response(200, 'successful') do
        before { ENV['STATS_API_KEY'] = 'dev-api-key-12345' }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:slack_uid) { 'TEST123456' }
        schema type: :object,
          properties: {
            user_id: { type: :integer, example: 42 },
            slack_uid: { type: :string, example: 'TEST123456' }
          }
        run_test!
      end

      response(404, 'not found') do
        before { ENV['STATS_API_KEY'] = 'dev-api-key-12345' }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:slack_uid) { 'U000000' }
        schema type: :object,
          properties: {
            error: { type: :string, example: 'User not found' },
            slack_uid: { type: :string, example: 'U000000' }
          }
        run_test!
      end
    end
  end

  path '/api/v1/users/{username}/trust_factor' do
    get('Get trust factor') do
      tags 'Users'
      description 'Get the trust level/factor for a user. Higher trust values indicate more verified activity.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username, Slack ID, or User ID'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:username) { 'testuser' }
        schema type: :object,
          properties: {
            trust_level: { type: :string, example: 'verified' },
            trust_value: { type: :integer, example: 2 }
          }
        run_test!
      end

      response(404, 'not found') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:username) { 'unknown_user' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/users/{username}/projects' do
    get('Get user projects') do
      tags 'Users'
      description 'Get a list of projects a user has coded on recently (last 30 days).'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
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

      response(404, 'not found') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:username) { 'unknown_user' }
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/users/{username}/project/{project_name}' do
    get('Get specific project stats') do
      tags 'Users'
      description 'Get detailed stats for a specific project.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username'
      parameter name: :project_name, in: :path, type: :string, description: 'Project Name'
      parameter name: :start, in: :query, schema: { type: :string, format: :date_time }, description: 'Stats start time (ISO 8601)'
      parameter name: :end, in: :query, schema: { type: :string, format: :date_time }, description: 'Stats end time (ISO 8601)'
      parameter name: :start_date, in: :query, schema: { type: :string, format: :date_time }, description: 'Start date (ISO 8601) for stats calculation'
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date_time }, description: 'End date (ISO 8601) for stats calculation'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:username) { 'testuser' }
        let(:project_name) { 'harbor' }
        let(:start) { nil }
        let(:end) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        run_test!
      end
    end
  end

  path '/api/v1/users/{username}/projects/details' do
    get('Get detailed project stats') do
      tags 'Users'
      description 'Get detailed breakdown of all user projects.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username'
      parameter name: :projects, in: :query, type: :string, description: 'Comma-separated list of projects to filter'
      parameter name: :since, in: :query, schema: { type: :string, format: :date_time }, description: 'Start time (ISO 8601) for project discovery'
      parameter name: :until, in: :query, schema: { type: :string, format: :date_time }, description: 'End time (ISO 8601) for project discovery'
      parameter name: :until_date, in: :query, schema: { type: :string, format: :date_time }, description: 'End time (ISO 8601) for project discovery'
      parameter name: :start, in: :query, schema: { type: :string, format: :date_time }, description: 'Stats start time (ISO 8601)'
      parameter name: :end, in: :query, schema: { type: :string, format: :date_time }, description: 'Stats end time (ISO 8601)'
      parameter name: :start_date, in: :query, schema: { type: :string, format: :date_time }, description: 'Start date (ISO 8601) for stats calculation'
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date_time }, description: 'End date (ISO 8601) for stats calculation'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:username) { 'testuser' }
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

  path '/api/v1/users/{username}/heartbeats/spans' do
    get('Get heartbeat spans') do
      tags 'Users'
      description 'Get time spans of coding activity.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username'
      parameter name: :start_date, in: :query, schema: { type: :string, format: :date }, description: 'Start date (YYYY-MM-DD)'
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date }, description: 'End date (YYYY-MM-DD)'
      parameter name: :project, in: :query, type: :string, description: 'Filter by specific project'
      parameter name: :filter_by_project, in: :query, type: :string, description: 'Filter by multiple projects (comma-separated)'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:username) { 'testuser' }
        let(:start_date) { Date.today.to_s }
        let(:end_date) { Date.today.to_s }
        let(:project) { nil }
        let(:filter_by_project) { nil }
        run_test!
      end
    end
  end
end
