require 'swagger_helper'

RSpec.describe 'Api::V1::Stats', type: :request do
  path '/api/v1/stats' do
    get('Get total coding time (Admin Only)') do
      tags 'Stats'
      description 'Returns the total coding time for all users, optionally filtered by user or date range. Requires admin privileges via STATS_API_KEY.'
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
        run_test!
      end

      response(401, 'unauthorized') do
        before { ENV['STATS_API_KEY'] = 'dev-api-key-12345' }
        let(:Authorization) { 'Bearer invalid_token' }
        let(:api_key) { 'invalid' }
        let(:start_date) { '2023-01-01' }
        let(:end_date) { '2023-12-31' }
        let(:username) { nil }
        let(:user_email) { nil }

        run_test! do |response|
          expect(response.status).to eq(401)
        end
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
    end

    path '/api/v1/users/{username}/heartbeats/spans' do
      get('Get user heartbeat spans') do
        tags 'Stats'
        description 'Returns heartbeat spans for a user, useful for visualizations.'
        produces 'application/json'

        parameter name: :username, in: :path, type: :string
        parameter name: :start_date, in: :query, schema: { type: :string, format: :date }
        parameter name: :end_date, in: :query, schema: { type: :string, format: :date }
        parameter name: :project, in: :query, type: :string, description: 'Filter by single project'
        parameter name: :filter_by_project, in: :query, type: :string, description: 'Filter by multiple projects (comma separated)'

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
                    start: { type: :number },
                    end: { type: :number },
                    project: { type: :string }
                  }
                }
              }
            }
          run_test!
        end
      end
    end

    path '/api/v1/users/{username}/trust_factor' do
      get('Get user trust factor') do
        tags 'Stats'
        description 'Returns the trust level and value for a user.'
        produces 'application/json'

        parameter name: :username, in: :path, type: :string

        response(200, 'successful') do
          let(:username) { 'testuser' }

          schema type: :object,
            properties: {
              trust_level: { type: :string, example: 'blue' },
              trust_value: { type: :integer, example: 3 }
            }
          run_test!
        end
      end
    end

    path '/api/v1/users/{username}/projects' do
      get('Get user project names') do
        tags 'Stats'
        description 'Returns a list of project names for a user from the last 30 days.'
        produces 'application/json'

        parameter name: :username, in: :path, type: :string

        response(200, 'successful') do
          let(:username) { 'testuser' }

          schema type: :object,
            properties: {
              projects: {
                type: :array,
                items: { type: :string }
              }
            }
          run_test!
        end
      end
    end

    path '/api/v1/users/{username}/project/{project_name}' do
      get('Get user project details') do
        tags 'Stats'
        description 'Returns details for a specific project.'
        produces 'application/json'

        parameter name: :username, in: :path, type: :string
        parameter name: :project_name, in: :path, type: :string
        parameter name: :start, in: :query, schema: { type: :string, format: :date }
        parameter name: :end, in: :query, schema: { type: :string, format: :date }
        parameter name: :start_date, in: :query, schema: { type: :string, format: :date }
        parameter name: :end_date, in: :query, schema: { type: :string, format: :date }

        response(200, 'successful') do
          let(:username) { 'testuser' }
          let(:project_name) { 'harbor' }
          let(:start) { nil }
          let(:end) { nil }
          let(:start_date) { nil }
          let(:end_date) { nil }

          schema type: :object,
            properties: {
              name: { type: :string },
              total_seconds: { type: :number },
              languages: { type: :array, items: { type: :string } },
              repo_url: { type: :string, nullable: true },
              total_heartbeats: { type: :integer },
              first_heartbeat: { type: :string, format: :date_time, nullable: true },
              last_heartbeat: { type: :string, format: :date_time, nullable: true }
            }
          run_test!
        end
      end
    end

    path '/api/v1/users/{username}/projects/details' do
      get('Get details for multiple projects') do
        tags 'Stats'
        description 'Returns details for multiple projects, or all projects in a time range.'
        produces 'application/json'

        parameter name: :username, in: :path, type: :string
        parameter name: :projects, in: :query, type: :string, description: 'Comma-separated project names'
        parameter name: :since, in: :query, schema: { type: :string, format: :date_time }
        parameter name: :until, in: :query, schema: { type: :string, format: :date_time }
        parameter name: :start, in: :query, schema: { type: :string, format: :date_time }
        parameter name: :end, in: :query, schema: { type: :string, format: :date_time }
        parameter name: :start_date, in: :query, schema: { type: :string, format: :date }
        parameter name: :end_date, in: :query, schema: { type: :string, format: :date }

        response(200, 'successful') do
          let(:username) { 'testuser' }
          let(:projects) { nil }
          let(:since) { nil }
          let(:until) { nil }
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
                    name: { type: :string },
                    total_seconds: { type: :number },
                    languages: { type: :array, items: { type: :string } },
                    repo_url: { type: :string, nullable: true },
                    total_heartbeats: { type: :integer },
                    first_heartbeat: { type: :string, format: :date_time, nullable: true },
                    last_heartbeat: { type: :string, format: :date_time, nullable: true }
                  }
                }
              }
            }
          run_test!
        end
      end
    end
  end

  path '/api/v1/users/{username}/stats' do
    get('Get user stats') do
      tags 'Stats'
      description 'Returns detailed coding stats for a specific user, including languages, projects, and total time.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :username, in: :path, type: :string, description: 'Username, Slack ID, or User ID'
      parameter name: :start_date, in: :query, schema: { type: :string, format: :date }, description: 'Start date (YYYY-MM-DD)'
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date }, description: 'End date (YYYY-MM-DD)'
      parameter name: :limit, in: :query, type: :integer, description: 'Limit number of results'
      parameter name: :features, in: :query, type: :string, description: 'Comma-separated list of features to include (e.g., languages,projects)'
      parameter name: :filter_by_project, in: :query, type: :string, description: 'Filter results by specific project names (comma-separated)'
      parameter name: :filter_by_category, in: :query, type: :string, description: 'Filter results by category (comma-separated)'
      parameter name: :boundary_aware, in: :query, type: :boolean, description: 'Use boundary aware calculation'
      parameter name: :total_seconds, in: :query, type: :boolean, description: 'Return only total seconds'

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
        schema type: :object,
          properties: {
            data: { '$ref' => '#/components/schemas/StatsSummary' },
            trust_factor: {
              type: :object,
              properties: {
                trust_level: { type: :string, example: 'blue' },
                trust_value: { type: :integer, example: 3 }
              }
            }
          }
        run_test!
      end

      response(403, 'forbidden') do
        before do
          user = User.create!(username: 'private_user', slack_uid: 'PRIVATE_123', allow_public_stats_lookup: false)
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
        description 'User has disabled public stats lookup'
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
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
