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
      parameter name: :date, in: :query, type: :string, format: :date, description: 'Date (YYYY-MM-DD)'

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
end
