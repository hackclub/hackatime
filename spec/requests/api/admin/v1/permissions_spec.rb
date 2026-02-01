require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::Permissions', type: :request do
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
                  id: { type: :integer },
                  username: { type: :string },
                  display_name: { type: :string, nullable: true },
                  slack_username: { type: :string, nullable: true },
                  github_username: { type: :string, nullable: true },
                  admin_level: { type: :string },
                  email_addresses: { type: :array, items: { type: :string } },
                  created_at: { type: :string },
                  updated_at: { type: :string }
                }
              }
            }
          }

        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
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
          admin_level: { type: :string, enum: [ 'superadmin', 'admin', 'viewer', 'default' ] }
        },
        required: [ 'admin_level' ]
      }

      response(200, 'successful') do
        schema type: :object,
          properties: {
            success: { type: :boolean },
            message: { type: :string },
            user: {
              type: :object,
              properties: {
                id: { type: :integer },
                username: { type: :string },
                display_name: { type: :string, nullable: true },
                admin_level: { type: :string },
                previous_admin_level: { type: :string },
                updated_at: { type: :string }
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
        run_test!
      end

      response(422, 'validation error handled') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'perm_val_user')
          EmailAddress.create!(user: u, email: 'perm_val@example.com')
          u
        end
        let(:id) { user.id }
        let(:permission) { { admin_level: 'invalid' } }
        run_test!
      end
    end
  end
end
