require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::Permissions', type: :request, openapi_spec: 'admin/swagger.yaml' do
  error_schema = {
    type: :object,
    properties: { error: { type: :string, example: 'Invalid admin level' } }
  }

  path '/api/admin/v1/permissions' do
    get('List Permissions') do
      tags 'Admin Resources'
      description 'List system permissions. Requires superadmin privileges.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :search, in: :query, type: :string, description: 'Search query'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, example: 42 },
                  username: { type: :string, example: 'orpheus' },
                  display_name: { type: :string, nullable: true, example: 'orpheus' },
                  slack_username: { type: :string, nullable: true, example: 'orpheus' },
                  github_username: { type: :string, nullable: true, example: 'orpheus' },
                  admin_level: { type: :string, example: 'admin' },
                  email_addresses: { type: :array, items: { type: :string, example: 'orpheus@hackclub.com' } },
                  created_at: { type: :string, example: '2024-03-20T15:30:00Z' },
                  updated_at: { type: :string, example: '2024-03-20T15:30:00Z' }
                }
              }
            }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:search) { 'foo' }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:search) { 'foo' }
        run_test!
      end
    end
  end

  path '/api/admin/v1/permissions/{id}' do
    patch('Update Permission') do
      tags 'Admin Resources'
      description 'Update a user\'s admin level. Requires superadmin privileges.'
      security [ AdminToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :id, in: :path, type: :string
      parameter name: :permission, in: :body, schema: {
        type: :object,
        properties: {
          admin_level: { type: :string, enum: [ 'superadmin', 'admin', 'viewer', 'default', 'ultraadmin' ], example: 'admin' }
        },
        required: [ 'admin_level' ]
      }

      response(200, 'successful') do
        schema type: :object,
          properties: {
            success: { type: :boolean, example: true },
            message: { type: :string, example: 'Admin level updated successfully' },
            user: {
              type: :object,
              properties: {
                id: { type: :integer, example: 42 },
                username: { type: :string, example: 'orpheus' },
                display_name: { type: :string, nullable: true, example: 'orpheus' },
                admin_level: { type: :string, example: 'superadmin' },
                previous_admin_level: { type: :string, example: 'default' },
                updated_at: { type: :string, example: '2024-03-20T15:30:00Z' }
              }
            }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'perm_user')
          EmailAddress.create!(user: u, email: 'perm@example.com')
          u
        end
        let(:id) { user.id }
        let(:permission) { { admin_level: 'superadmin' } }
        run_test!
      end

      response(404, 'not found handled') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:id) { '0' }
        let(:permission) { { admin_level: 'superadmin' } }
        schema(**error_schema)
        run_test!
      end

      response(422, 'validation error handled — Returned when admin_level is not a valid admin level. Body is { error: "Invalid admin level" }.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'perm_val_user')
          EmailAddress.create!(user: u, email: 'perm_val@example.com')
          u
        end
        let(:id) { user.id }
        let(:permission) { { admin_level: 'invalid' } }
        schema(**error_schema)
        run_test!
      end

      response(403, 'forbidden — Returned when the caller is not allowed to set the target to the requested level (e.g. attempting to change your own admin level). Body is { error: <denial message> }.') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:id) { AdminApiKey.find_by!(token: 'dev-admin-api-key-12345').user.id }
        let(:permission) { { admin_level: 'admin' } }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:id) { '1' }
        let(:permission) { { admin_level: 'superadmin' } }
        run_test!
      end
    end
  end
end
