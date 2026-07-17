require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::AdminUsers', type: :request, openapi_spec: 'admin/swagger.yaml' do
  path '/api/admin/v1/check' do
    get('Check status') do
      tags 'Admin'
      description 'Check if admin API authentication is working. Returns metadata about the Admin API key or OAuth token and its authorizing user.'
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        run_test!
      end

      response(401, 'unauthorized — Returned when the bearer token is missing/invalid, the OAuth application is no longer eligible for admin access, or the associated user is not an admin/superadmin/viewer/ultraadmin. Demoted users have their Admin API key revoked.') do
        let(:Authorization) { "Bearer not-a-real-admin-token" }
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
                  id: { type: :integer, example: 42, description: 'User ID' },
                  username: { type: :string, nullable: true, example: 'orpheus', description: 'Username' },
                  email: { type: :string, example: 'orpheus@hackclub.com', description: 'Primary email or "no email"' }
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
