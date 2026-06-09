require 'swagger_helper'

RSpec.describe 'Api::V1::Leaderboard', type: :request do
  let(:leaderboard_user) do
    User.find_by(slack_uid: 'LEADERBOARD_USER') || User.create!(
      slack_uid: 'LEADERBOARD_USER',
      username: 'leaderboarduser',
      slack_username: 'leaderboarduser',
      timezone: 'UTC'
    )
  end

  path '/api/v1/leaderboard' do
    get('Get daily leaderboard (Alias)') do
      tags 'Leaderboard'
      description 'Alias for /api/v1/leaderboard/daily. Returns the daily leaderboard. Public, no authentication required.'
      produces 'application/json'

      response(200, 'successful', document: false) do
        before do
          board = Leaderboard.create!(
            start_date: Date.current,
            period_type: :daily,
            finished_generating_at: Time.current
          )
          board.entries.create!(user: leaderboard_user, total_seconds: 3600)
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

      response(503, 'service unavailable — Leaderboard is being generated', document: false) do
        before do
          Leaderboard.destroy_all
          Rails.cache.clear
        end
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/leaderboard/daily' do
    get('Get daily leaderboard') do
      tags 'Leaderboard'
      description 'Returns the daily leaderboard of coding time. Public, no authentication required. The leaderboard is cached and regenerated periodically.'
      produces 'application/json'

      response(200, 'successful') do
        before do
          board = Leaderboard.create!(
            start_date: Date.current,
            period_type: :daily,
            finished_generating_at: Time.current
          )
          board.entries.create!(user: leaderboard_user, total_seconds: 3600)
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

      response(503, 'service unavailable — Leaderboard is being generated') do
        before do
          Leaderboard.destroy_all
          Rails.cache.clear
        end
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/leaderboard/weekly' do
    get('Get weekly leaderboard') do
      tags 'Leaderboard'
      description 'Returns the weekly leaderboard of coding time (last 7 days). Public, no authentication required.'
      produces 'application/json'

      response(200, 'successful') do
        before do
          board = Leaderboard.create!(
            start_date: Date.current,
            period_type: :last_7_days,
            finished_generating_at: Time.current
          )
          board.entries.create!(user: leaderboard_user, total_seconds: 3600 * 7)
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

      response(503, 'service unavailable — Leaderboard is being generated') do
        before do
          Leaderboard.destroy_all
          Rails.cache.clear
        end
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
