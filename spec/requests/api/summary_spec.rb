require 'swagger_helper'

RSpec.describe 'Api::Summary', type: :request do
  path '/api/summary' do
    get('Get WakaTime-compatible summary') do
      tags 'WakaTime Compatibility'
      description 'Returns a public summary of coding activity in a format compatible with WakaTime clients.'
      produces 'application/json'

      parameter name: :start, in: :query, schema: { type: :string, format: :date }, description: 'Start date (YYYY-MM-DD)'
      parameter name: :end, in: :query, schema: { type: :string, format: :date }, description: 'End date (YYYY-MM-DD)'
      parameter name: :from, in: :query, schema: { type: :string, format: :date }, required: false, description: 'Alias for start (YYYY-MM-DD)'
      parameter name: :to, in: :query, schema: { type: :string, format: :date }, required: false, description: 'Alias for end (YYYY-MM-DD)'
      parameter name: :range, in: :query, type: :string, required: false, description: 'Predefined range (e.g. today, yesterday, week, month). Alias for interval.'
      parameter name: :interval, in: :query, type: :string, description: 'Interval (e.g. today, yesterday, week, month)'
      parameter name: :project, in: :query, type: :string, description: 'Project name (optional)'
      parameter name: :user_id, in: :query, type: :string, required: true, description: 'User identifier (slack_uid, username, hca_id, or numeric ID)'
      parameter name: :user, in: :query, type: :string, description: 'Deprecated: use user_id instead. Kept for backwards compatibility.'

      response(200, 'successful') do
        let(:test_user) { User.create!(slack_uid: "USUMMARY#{SecureRandom.hex(4)}", timezone: 'UTC', allow_public_stats_lookup: true) }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start) { '2023-01-01' }
        let(:end) { '2023-01-31' }
        let(:interval) { nil }
        let(:from) { nil }
        let(:to) { nil }
        let(:range) { nil }
        let(:project) { nil }
        let(:user_id) { test_user.slack_uid }
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

      response(400, 'missing user_id') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start) { '2023-01-01' }
        let(:end) { '2023-01-31' }
        let(:interval) { nil }
        let(:from) { nil }
        let(:to) { nil }
        let(:range) { nil }
        let(:project) { nil }
        let(:user_id) { nil }
        let(:user) { nil }
        run_test!
      end

      response(400, 'invalid date range') do
        let(:date_test_user) { User.create!(slack_uid: "UDATE#{SecureRandom.hex(4)}", timezone: 'UTC', allow_public_stats_lookup: true) }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start) { 'invalid-date' }
        let(:end) { '2023-01-31' }
        let(:interval) { nil }
        let(:from) { nil }
        let(:to) { nil }
        let(:range) { nil }
        let(:project) { nil }
        let(:user_id) { date_test_user.slack_uid }
        let(:user) { nil }
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start) { '2023-01-01' }
        let(:end) { '2023-01-31' }
        let(:interval) { nil }
        let(:from) { nil }
        let(:to) { nil }
        let(:range) { nil }
        let(:project) { nil }
        let(:user_id) { 'nonexistent-user-id' }
        let(:user) { nil }
        run_test!
      end

      response(403, 'user has disabled public stats') do
        let(:private_user) { User.create!(slack_uid: 'UPRIVATE', timezone: 'UTC', allow_public_stats_lookup: false) }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start) { '2023-01-01' }
        let(:end) { '2023-01-31' }
        let(:interval) { nil }
        let(:from) { nil }
        let(:to) { nil }
        let(:range) { nil }
        let(:project) { nil }
        let(:user_id) { private_user.slack_uid }
        let(:user) { nil }
        run_test!
      end
    end
  end
end
