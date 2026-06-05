require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::LeaderboardShadowbans', type: :request do
  path '/api/admin/v1/leaderboard_shadowbans' do
    get('List Leaderboard Shadowbans') do
      tags 'Admin Resources'
      description 'List users hidden from public leaderboards. Requires superadmin privileges.'
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:actor) { AdminApiKey.find_by!(token: 'dev-admin-api-key-12345').user }
        let(:shadowbanned_user) { User.create!(username: 'rswag_lb_shadowbanned', timezone: 'UTC') }

        before do
          shadowbanned_user.set_leaderboard_shadowban(banned: true, changed_by_user: actor, reason: 'inflated activity')
        end

        schema type: :object,
          properties: {
            leaderboard_shadowbans: {
              type: :array,
              items: { '$ref' => '#/components/schemas/LeaderboardShadowbanUser' }
            }
          }

        run_test!
      end
    end

    post('Create Leaderboard Shadowban') do
      tags 'Admin Resources'
      description 'Hide a user from public leaderboards. Requires superadmin privileges and a reason.'
      security [ AdminToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          user_id: { type: :integer },
          reason: { type: :string },
          leaderboard_shadowban_expires_at: { type: :string, format: 'date-time', nullable: true }
        },
        required: [ 'user_id', 'reason' ]
      }

      response(201, 'created') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { User.create!(username: 'rswag_lb_create', timezone: 'UTC') }
        let(:payload) { { user_id: target.id, reason: 'fake leaderboard activity', leaderboard_shadowban_expires_at: 1.week.from_now.iso8601 } }

        schema type: :object,
          properties: {
            success: { type: :boolean },
            message: { type: :string },
            user: { '$ref' => '#/components/schemas/LeaderboardShadowbanUser' }
          }

        run_test!
      end

      response(422, 'validation error') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { User.create!(username: 'rswag_lb_invalid', timezone: 'UTC') }
        let(:payload) { { user_id: target.id, reason: '' } }

        run_test!
      end
    end
  end

  path '/api/admin/v1/leaderboard_shadowbans/search_users' do
    get('Search Users for Leaderboard Shadowbans') do
      tags 'Admin Resources'
      description 'Search users and include their current leaderboard shadowban metadata. Requires superadmin privileges.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :query, in: :query, type: :string, description: 'Search query'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:query) { 'rswag_lb_search' }

        before do
          User.create!(username: query, timezone: 'UTC')
        end

        schema type: :object,
          properties: {
            users: {
              type: :array,
              items: { '$ref' => '#/components/schemas/LeaderboardShadowbanUser' }
            }
          }

        run_test!
      end
    end
  end

  path '/api/admin/v1/leaderboard_shadowbans/{user_id}' do
    delete('Delete Leaderboard Shadowban') do
      tags 'Admin Resources'
      description 'Remove a user from the leaderboard shadowban list. Requires superadmin privileges.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :path, type: :integer

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:actor) { AdminApiKey.find_by!(token: 'dev-admin-api-key-12345').user }
        let(:target) { User.create!(username: 'rswag_lb_delete', timezone: 'UTC') }
        let(:user_id) { target.id }

        before do
          target.set_leaderboard_shadowban(banned: true, changed_by_user: actor, reason: 'fake data')
        end

        schema type: :object,
          properties: {
            success: { type: :boolean },
            message: { type: :string },
            user: { '$ref' => '#/components/schemas/LeaderboardShadowbanUser' }
          }

        run_test!
      end

      response(404, 'not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { 0 }

        run_test!
      end
    end
  end
end
