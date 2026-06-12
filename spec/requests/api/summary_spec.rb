require 'swagger_helper'

RSpec.describe 'Api::Summary', type: :request do
  path '/api/summary' do
    get('Get WakaTime-compatible summary') do
      tags 'WakaTime Compatibility'
      description 'Returns a summary of coding activity in a format compatible with WakaTime clients. ' \
                  'This endpoint does NOT authenticate any API token: access is gated solely by the target ' \
                  'user (identified by user_id/user) having allow_public_stats_lookup enabled. No caller ' \
                  'credentials are required or verified.'
      produces 'application/json'

      parameter name: :start, in: :query, schema: { type: :string, format: :date }, description: 'Start date (YYYY-MM-DD). Requires "end"/"to" to be set as well to form an explicit range.'
      parameter name: :from, in: :query, schema: { type: :string, format: :date }, description: 'Alias for "start". Used when "start" is absent.'
      parameter name: :end, in: :query, schema: { type: :string, format: :date }, description: 'End date (YYYY-MM-DD). Requires "start"/"from" to be set as well to form an explicit range.'
      parameter name: :to, in: :query, schema: { type: :string, format: :date }, description: 'Alias for "end". Used when "end" is absent.'
      parameter name: :interval, in: :query, type: :string, description: 'Interval keyword. One of: today, yesterday, week, 7_days, last_7_days, month, 30_days, last_30_days, 6_months, last_6_months, year, 12_months, last_12_months, last_year, any, all_time. Defaults to all_time when neither interval nor range is given; unknown values fall back to today.'
      parameter name: :range, in: :query, type: :string, description: 'Fallback interval keyword used when "interval" is absent. Accepts the same values as "interval".'
      parameter name: :user_id, in: :query, type: :string, required: true, description: 'User identifier (slack_uid, username, hca_id, or numeric ID)'
      parameter name: :user, in: :query, type: :string, description: 'Deprecated: use user_id instead. Kept for backwards compatibility.'

      response(200, 'successful') do
        let(:test_user) { User.create!(slack_uid: "USUMMARY#{SecureRandom.hex(4)}", timezone: 'UTC', allow_public_stats_lookup: true) }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start) { '2023-01-01' }
        let(:end) { '2023-01-31' }
        let(:interval) { nil }
        let(:range) { nil }
        let(:from) { nil }
        let(:to) { nil }
        let(:user_id) { test_user.slack_uid }
        let(:user) { nil }
        schema type: :object,
          properties: {
            user_id: { type: :string, nullable: true, example: 'U0266FRGP' },
            from: { type: :string, format: :date_time, example: '2023-01-01T00:00:00Z' },
            to: { type: :string, format: :date_time, example: '2023-01-31T23:59:59Z' },
            projects: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  key: { type: :string, example: 'hackatime' },
                  total: { type: :number, example: 21600.0 }
                }
              }
            },
            languages: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  key: { type: :string, example: 'Ruby' },
                  total: { type: :number, example: 18000.0 }
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
        let(:range) { nil }
        let(:from) { nil }
        let(:to) { nil }
        let(:user_id) { nil }
        let(:user) { nil }
        run_test!
      end

      response(400, 'invalid date range') do
        let(:date_test_user) { User.create!(slack_uid: "UDATE#{SecureRandom.hex(4)}", timezone: 'UTC', allow_public_stats_lookup: true) }
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        let(:start) { nil }
        let(:end) { nil }
        let(:interval) { nil }
        let(:range) { nil }
        let(:from) { 'invalid-date' }
        let(:to) { '2023-01-31' }
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
        let(:range) { nil }
        let(:from) { nil }
        let(:to) { nil }
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
        let(:range) { nil }
        let(:from) { nil }
        let(:to) { nil }
        let(:user_id) { private_user.slack_uid }
        let(:user) { nil }
        run_test!
      end
    end
  end
end
