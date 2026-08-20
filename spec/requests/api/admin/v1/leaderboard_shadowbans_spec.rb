require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::LeaderboardShadowbans', type: :request, openapi_spec: 'admin/swagger.yaml' do
  error_schema = {
    type: :object,
    properties: { error: { type: :string, example: 'User not found' } }
  }

  error_with_details_schema = {
    type: :object,
    properties: {
      error: { type: :string, example: 'Validation failed' },
      errors: { type: :array, items: { type: :string, example: 'Leaderboard shadowban expires at is not a valid datetime' } }
    }
  }

  path '/api/admin/v1/leaderboard_shadowbans' do
    get('List Leaderboard Shadowbans') do
      tags 'Admin Resources'
      description 'List users hidden from public leaderboards. Requires admin privileges.'
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

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        run_test!
      end

      response(403, 'forbidden — Returned when the caller cannot manage leaderboard shadowbans (e.g. a viewer-level admin).') do
        let(:Authorization) { "Bearer viewer-admin-api-key-rswag" }
        before do
          u = User.create!(username: 'rswag_lb_viewer', timezone: 'UTC', admin_level: :viewer)
          AdminApiKey.create!(user: u, name: 'Viewer Key', token: 'viewer-admin-api-key-rswag')
        end
        schema(**error_schema)
        run_test!
      end
    end

    post('Create Leaderboard Shadowban') do
      tags 'Admin Resources'
      description 'Hide a user from public leaderboards. Requires admin privileges and a reason.'
      security [ AdminToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          user_id: { type: :integer, example: 42 },
          reason: { type: :string, example: 'inflated activity' },
          leaderboard_shadowban_expires_at: { type: :string, format: 'date-time', nullable: true, example: '2024-03-27T15:30:00Z' }
        },
        required: [ 'user_id', 'reason' ]
      }

      response(201, 'created') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { User.create!(username: 'rswag_lb_create', timezone: 'UTC') }
        let(:payload) { { user_id: target.id, reason: 'fake leaderboard activity', leaderboard_shadowban_expires_at: 1.week.from_now.iso8601 } }

        schema type: :object,
          properties: {
            success: { type: :boolean, example: true },
            message: { type: :string, example: 'User shadowbanned from leaderboards' },
            user: { '$ref' => '#/components/schemas/LeaderboardShadowbanUser' }
          }

        run_test!
      end

      response(422, 'validation error — Returned when the shadowban could not be saved (model validation errors).') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { User.create!(username: 'rswag_lb_invalid', timezone: 'UTC') }
        let(:payload) { { user_id: target.id, reason: 'bad expiry', leaderboard_shadowban_expires_at: 'not-a-date' } }
        schema(**error_with_details_schema)
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { user_id: 0, reason: 'whatever' } }
        schema(**error_schema)
        run_test!
      end

      response(403, 'forbidden (cannot manage that user) — Returned when the change is rejected without validation errors (e.g. the target outranks the caller).') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { User.create!(username: 'rswag_lb_peer', timezone: 'UTC', admin_level: :ultraadmin) }
        let(:payload) { { user_id: target.id, reason: 'fake activity' } }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:payload) { { user_id: 1, reason: 'fake activity' } }
        run_test!
      end
    end
  end

  path '/api/admin/v1/leaderboard_shadowbans/search_users' do
    get('Search Users for Leaderboard Shadowbans') do
      tags 'Admin Resources'
      description 'Search users and include their current leaderboard shadowban metadata. Requires admin privileges.'
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

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:query) { 'foo' }
        run_test!
      end
    end
  end

  path '/api/admin/v1/leaderboard_shadowbans/{user_id}' do
    delete('Delete Leaderboard Shadowban') do
      tags 'Admin Resources'
      description 'Remove a user from the leaderboard shadowban list. Requires admin privileges.'
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
            success: { type: :boolean, example: true },
            message: { type: :string, example: 'User removed from leaderboard shadowban list' },
            user: { '$ref' => '#/components/schemas/LeaderboardShadowbanUser' }
          }

        run_test!
      end

      response(404, 'not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { 0 }
        schema(**error_schema)
        run_test!
      end

      response(403, 'forbidden (cannot manage that user) — Returned when the change is rejected without validation errors (e.g. the target outranks the caller).') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:target) { User.create!(username: 'rswag_lb_del_peer', timezone: 'UTC', admin_level: :ultraadmin) }
        let(:user_id) { target.id }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:user_id) { 1 }
        run_test!
      end
    end
  end
end
