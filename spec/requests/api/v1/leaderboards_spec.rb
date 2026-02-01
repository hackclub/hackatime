require 'swagger_helper'

RSpec.describe 'Api::V1::Leaderboard', type: :request do
  path '/api/v1/leaderboard' do
    get('Get daily leaderboard (Alias)') do
      tags 'Leaderboard'
      description 'Alias for /api/v1/leaderboard/daily. Returns the daily leaderboard.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        before do
          entry_double = double(user: double(id: 1, display_name: 'testuser', avatar_url: 'http://example.com/avatar'), total_seconds: 3600)
          entries_relation = double
          allow(entries_relation).to receive(:includes).with(:user).and_return(entries_relation)
          allow(entries_relation).to receive(:order).with(total_seconds: :desc).and_return([ entry_double ])

          allow(LeaderboardService).to receive(:get).and_return(
            double(
              period_type: 'daily',
              start_date: Date.today,
              date_range_text: 'Today',
              finished_generating_at: Time.now,
              entries: entries_relation
            )
          )
        end

        schema type: :object,
          properties: {
            period: { type: :string, example: 'daily' },
            start_date: { type: :string, format: :date, example: '2024-03-20' },
            date_range: { type: :string, example: 'Wed, Mar 20, 2024' },
            generated_at: { type: :string, format: :date_time, example: '2024-03-20T10:00:00Z' },
            entries: {
              type: :array,
              items: { '$ref' => '#/components/schemas/LeaderboardEntry' }
            }
          }
        run_test!
      end
    end
  end

  path '/api/v1/leaderboard/daily' do
    get('Get daily leaderboard') do
      tags 'Leaderboard'
      description 'Returns the daily leaderboard of coding time. Requires STATS_API_KEY. The leaderboard is cached and regenerated periodically.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        before do
          entry_double = double(user: double(id: 1, display_name: 'testuser', avatar_url: 'http://example.com/avatar'), total_seconds: 3600)
          entries_relation = double
          allow(entries_relation).to receive(:includes).with(:user).and_return(entries_relation)
          allow(entries_relation).to receive(:order).with(total_seconds: :desc).and_return([ entry_double ])

          allow(LeaderboardService).to receive(:get).and_return(
            double(
              period_type: 'daily',
              start_date: Date.today,
              date_range_text: 'Today',
              finished_generating_at: Time.now,
              entries: entries_relation
            )
          )
        end

        schema type: :object,
          properties: {
            period: { type: :string, example: 'daily' },
            start_date: { type: :string, format: :date, example: '2024-03-20' },
            date_range: { type: :string, example: 'Wed, Mar 20, 2024' },
            generated_at: { type: :string, format: :date_time, example: '2024-03-20T10:00:00Z' },
            entries: {
              type: :array,
              items: { '$ref' => '#/components/schemas/LeaderboardEntry' }
            }
          }
        run_test!
      end

      # response(401, 'unauthorized') do
      #   let(:Authorization) { 'Bearer invalid_token' }
      #   let(:api_key) { "invalid" }
      #   schema '$ref' => '#/components/schemas/Error'
      #   run_test!
      # end

      response(503, 'service unavailable') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        description 'Leaderboard is currently being generated'
        before do
          allow(LeaderboardService).to receive(:get).and_return(nil)
        end
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/leaderboard/weekly' do
    get('Get weekly leaderboard') do
      tags 'Leaderboard'
      description 'Returns the weekly leaderboard of coding time (last 7 days). Requires STATS_API_KEY.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { "dev-api-key-12345" }
        before do
          entry_double = double(user: double(id: 1, display_name: 'testuser', avatar_url: 'http://example.com/avatar'), total_seconds: 3600 * 7)
          entries_relation = double
          allow(entries_relation).to receive(:includes).with(:user).and_return(entries_relation)
          allow(entries_relation).to receive(:order).with(total_seconds: :desc).and_return([ entry_double ])

          allow(LeaderboardService).to receive(:get).and_return(
            double(
              period_type: 'last_7_days',
              start_date: Date.today - 7.days,
              date_range_text: 'Last 7 Days',
              finished_generating_at: Time.now,
              entries: entries_relation
            )
          )
        end

        schema type: :object,
          properties: {
            period: { type: :string, example: 'last_7_days' },
            start_date: { type: :string, format: :date, example: '2024-03-13' },
            date_range: { type: :string, example: 'Mar 13 - Mar 20, 2024' },
            generated_at: { type: :string, format: :date_time, example: '2024-03-20T10:00:00Z' },
            entries: {
              type: :array,
              items: { '$ref' => '#/components/schemas/LeaderboardEntry' }
            }
          }
        run_test!
      end

      # response(401, 'unauthorized') do
      #   let(:Authorization) { 'Bearer invalid_token' }
      #   let(:api_key) { "invalid" }
      #   schema '$ref' => '#/components/schemas/Error'
      #   run_test!
      # end
    end
  end
end
