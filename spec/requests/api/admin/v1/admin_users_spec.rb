require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::AdminUsers', type: :request do
  path '/api/admin/v1/user/info' do
    get('Get user info (Admin)') do
      tags 'Admin'
      description 'Get detailed info about a user. Requires superadmin/admin privileges.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'User ID'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { '1' }
        let(:date) { '2023-01-01' }
        run_test!
      end
    end
  end

  path '/api/admin/v1/user/heartbeats' do
    get('Get user heartbeats (Admin)') do
      tags 'Admin'
      description 'Get raw heartbeats for a user.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'User ID'
      parameter name: :date, in: :query, schema: { type: :string, format: :date }, description: 'Date (YYYY-MM-DD)'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { '1' }
        let(:date) { '2023-01-01' }
        run_test!
      end
    end
  end

  path '/api/admin/v1/check' do
    get('Check status') do
      tags 'Admin'
      description 'Check if admin API is working.'
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        run_test!
      end
    end
  end

  path '/api/admin/v1/banned_users' do
    get('Get banned users') do
      tags 'Admin'
      description 'Get a list of banned users.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :limit, in: :query, type: :integer, required: false, description: 'Max results to return (default: 200, max: 1000)'
      parameter name: :offset, in: :query, type: :integer, required: false, description: 'Number of results to skip for pagination (default: 0)'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            banned_users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, description: 'User ID' },
                  username: { type: :string, description: 'Username' },
                  email: { type: :string, description: 'Primary email or "no email"' }
                }
              }
            }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer viewer-api-key" }
        run_test!
      end
    end
  end
end
