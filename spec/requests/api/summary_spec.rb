require 'swagger_helper'

RSpec.describe 'Api::Summary', type: :request do
  path '/api/summary' do
    get('Get WakaTime-compatible summary') do
      tags 'WakaTime Compatibility'
      description 'Returns a summary of coding activity in a format compatible with WakaTime clients. This endpoint supports querying by date range, interval, or specific user (admin/privileged only).'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :start, in: :query, schema: { type: :string, format: :date }, description: 'Start date (YYYY-MM-DD)'
      parameter name: :end, in: :query, schema: { type: :string, format: :date }, description: 'End date (YYYY-MM-DD)'
      parameter name: :interval, in: :query, type: :string, description: 'Interval (e.g. today, yesterday, week, month)'
      parameter name: :project, in: :query, type: :string, description: 'Project name (optional)'
      parameter name: :user, in: :query, type: :string, description: 'Slack UID of the user (optional, for admin use)'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start) { '2023-01-01' }
        let(:end) { '2023-01-31' }
        let(:interval) { nil }
        let(:project) { nil }
        let(:user) { nil }
        schema type: :object,
          properties: {
            user_id: { type: :string, nullable: true },
            from: { type: :string, format: :date_time },
            to: { type: :string, format: :date_time },
            projects: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  key: { type: :string },
                  total: { type: :number }
                }
              }
            },
            languages: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  key: { type: :string },
                  total: { type: :number }
                }
              }
            },
            editors: { type: :object, nullable: true },
            operating_systems: { type: :object, nullable: true },
            machines: { type: :object, nullable: true },
            categories: { type: :object, nullable: true },
            branches: { type: :object, nullable: true },
            entities: { type: :object, nullable: true },
            labels: { type: :object, nullable: true }
          }
        run_test!
      end

      response(400, 'bad request') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start) { 'invalid-date' }
        let(:end) { '2023-01-31' }
        let(:interval) { nil }
        let(:project) { nil }
        let(:user) { nil }
        run_test!
      end
    end
  end
end
