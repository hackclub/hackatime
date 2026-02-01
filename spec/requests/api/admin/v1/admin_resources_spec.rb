require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::Resources', type: :request do
  path '/api/admin/v1/admin_api_keys' do
    get('List Admin API Keys') do
      tags 'Admin Resources'
      description 'List all admin API keys.'
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        schema type: :object,
          properties: {
            admin_api_keys: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  name: { type: :string },
                  token_preview: { type: :string },
                  user: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      username: { type: :string },
                      display_name: { type: :string },
                      admin_level: { type: :string }
                    }
                  },
                  created_at: { type: :string, format: :date_time },
                  revoked_at: { type: :string, format: :date_time, nullable: true },
                  active: { type: :boolean }
                }
              }
            }
          }
        run_test!
      end
    end

    post('Create Admin API Key') do
      tags 'Admin Resources'
      description 'Create a new admin API key.'
      security [ AdminToken: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :payload, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string }
        }
      }

      response(201, 'created') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { name: 'New Key' } }
        schema type: :object,
          properties: {
            success: { type: :boolean },
            message: { type: :string },
            admin_api_key: {
              type: :object,
              properties: {
                id: { type: :integer },
                name: { type: :string },
                token: { type: :string },
                created_at: { type: :string, format: :date_time }
              }
            }
          }
        run_test!
      end
    end
  end

  path '/api/admin/v1/admin_api_keys/{id}' do
    parameter name: :id, in: :path, type: :string

    get('Show Admin API Key') do
      tags 'Admin Resources'
      description 'Show details of an admin API key.'
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:api_key) do
          u = User.create!(username: 'key_owner')
          EmailAddress.create!(user: u, email: 'key_owner@example.com')
          AdminApiKey.create!(user: u, name: 'Show Key')
        end
        let(:id) { api_key.id }
        schema type: :object,
          properties: {
            id: { type: :integer },
            name: { type: :string },
            token_preview: { type: :string },
            user: {
              type: :object,
              properties: {
                id: { type: :integer },
                username: { type: :string },
                display_name: { type: :string },
                admin_level: { type: :string }
              }
            },
            created_at: { type: :string, format: :date_time },
            revoked_at: { type: :string, format: :date_time, nullable: true },
            active: { type: :boolean }
          }
        run_test!
      end
    end

    delete('Revoke Admin API Key') do
      tags 'Admin Resources'
      description 'Revoke/Delete an admin API key.'
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:api_key_to_revoke) do
          u = User.create!(username: 'revoke_me')
          EmailAddress.create!(user: u, email: 'revoke@example.com')
          AdminApiKey.create!(user: u, name: 'Revoke Key')
        end
        let(:id) { api_key_to_revoke.id }
        schema type: :object,
          properties: {
            success: { type: :boolean },
            message: { type: :string }
          }
        run_test!
      end
    end
  end

  path '/api/admin/v1/trust_level_audit_logs' do
    get('List Trust Level Audit Logs') do
      tags 'Admin Resources'
      description 'List audit logs for trust level changes.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :user_id, in: :query, type: :string, description: 'Filter by User ID', required: false
      parameter name: :admin_id, in: :query, type: :string, description: 'Filter by Admin ID', required: false
      parameter name: :user_search, in: :query, type: :string, description: 'Search user (fuzzy)', required: false
      parameter name: :admin_search, in: :query, type: :string, description: 'Search admin (fuzzy)', required: false
      parameter name: :trust_level_filter, in: :query, schema: { type: :string, enum: %w[all to_convicted to_trusted to_suspected to_unscored] }, description: 'Filter by trust level change', required: false

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { nil }
        let(:admin_id) { nil }
        let(:user_search) { nil }
        let(:admin_search) { nil }
        let(:trust_level_filter) { nil }

        schema type: :object,
          properties: {
            audit_logs: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  user: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      username: { type: :string },
                      display_name: { type: :string }
                    }
                  },
                  previous_trust_level: { type: :string, nullable: true },
                  new_trust_level: { type: :string, nullable: true },
                  changed_by: {
                    type: :object,
                    properties: {
                      id: { type: :integer },
                      username: { type: :string },
                      display_name: { type: :string },
                      admin_level: { type: :string }
                    }
                  },
                  reason: { type: :string, nullable: true },
                  notes: { type: :string, nullable: true },
                  created_at: { type: :string }
                }
              }
            },
            total_count: { type: :integer }
          }
        run_test!
      end
    end
  end

  path '/api/admin/v1/trust_level_audit_logs/{id}' do
    get('Show Trust Level Audit Log') do
      tags 'Admin Resources'
      description 'Show details of a trust level audit log.'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :id, in: :path, type: :string

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'audit_user')
          EmailAddress.create!(user: u, email: 'audit@example.com')
          u
        end
        let(:admin) do
          User.find_by(username: 'testuser') || begin
            u = User.create!(username: 'testuser', admin_level: 'superadmin')
            EmailAddress.create!(user: u, email: 'admin@example.com')
            u
          end
        end
        let(:log) do
          TrustLevelAuditLog.create!(
            user: user,
            changed_by: admin,
            previous_trust_level: 'blue',
            new_trust_level: 'green',
            reason: 'Manual verification',
            notes: 'Looks good'
          )
        end
        let(:id) { log.id }
        schema type: :object,
          properties: {
            id: { type: :integer },
            user: {
              type: :object,
              properties: {
                id: { type: :integer },
                username: { type: :string },
                display_name: { type: :string },
                current_trust_level: { type: :string }
              }
            },
            previous_trust_level: { type: :string, nullable: true },
            new_trust_level: { type: :string, nullable: true },
            changed_by: {
              type: :object,
              properties: {
                id: { type: :integer },
                username: { type: :string },
                display_name: { type: :string },
                admin_level: { type: :string }
              }
            },
            reason: { type: :string, nullable: true },
            notes: { type: :string, nullable: true },
            created_at: { type: :string, format: :date_time },
            updated_at: { type: :string, format: :date_time }
          }
        run_test!
      end
    end
  end

  path '/api/admin/v1/deletion_requests' do
    get('List Deletion Requests') do
      tags 'Admin Resources'
      description 'List pending deletion requests.'
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        schema type: :object,
          properties: {
            pending: {
              type: :array,
              items: { '$ref' => '#/components/schemas/DeletionRequest' }
            },
            approved: {
              type: :array,
              items: { '$ref' => '#/components/schemas/DeletionRequest' }
            },
            completed: {
              type: :array,
              items: { '$ref' => '#/components/schemas/DeletionRequest' }
            }
          }
        run_test!
      end
    end
  end

  path '/api/admin/v1/deletion_requests/{id}' do
    parameter name: :id, in: :path, type: :string

    get('Show Deletion Request') do
      tags 'Admin Resources'
      description 'Show details of a deletion request.'
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'delete_me')
          EmailAddress.create!(user: u, email: 'delete@example.com')
          u
        end
        let(:deletion_request) { DeletionRequest.create!(user: user, status: 0, requested_at: Time.current) }
        let(:id) { deletion_request.id }
        schema '$ref' => '#/components/schemas/DeletionRequest'
        run_test!
      end
    end
  end

  path '/api/admin/v1/deletion_requests/{id}/approve' do
    post('Approve Deletion Request') do
      tags 'Admin Resources'
      description 'Approve and execute a user deletion request.'
      security [ AdminToken: [] ]
      produces 'application/json'
      parameter name: :id, in: :path, type: :string

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'reject_me')
          EmailAddress.create!(user: u, email: 'reject@example.com')
          u
        end
        let(:deletion_request) { DeletionRequest.create!(user: user, status: 0, requested_at: Time.current) }
        let(:id) { deletion_request.id }
        schema type: :object,
          properties: {
            success: { type: :boolean },
            message: { type: :string },
            deletion_request: {
              type: :object,
              properties: {
                id: { type: :integer },
                user_id: { type: :integer },
                user: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    username: { type: :string },
                    display_name: { type: :string }
                  }
                },
                status: { type: :string, enum: %w[pending approved cancelled completed] },
                requested_at: { type: :string, format: :date_time },
                scheduled_deletion_at: { type: :string, format: :date_time, nullable: true },
                completed_at: { type: :string, format: :date_time, nullable: true },
                admin_approved_by: { type: :object, nullable: true },
                created_at: { type: :string, format: :date_time },
                updated_at: { type: :string, format: :date_time }
              }
            }
          }
        run_test!
      end
    end
  end

  path '/api/admin/v1/deletion_requests/{id}/reject' do
    post('Reject Deletion Request') do
      tags 'Admin Resources'
      description 'Reject a user deletion request.'
      security [ AdminToken: [] ]
      produces 'application/json'
      parameter name: :id, in: :path, type: :string

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user) do
          u = User.create!(username: 'reject_me_please')
          EmailAddress.create!(user: u, email: 'reject_me_please@example.com')
          u
        end
        let(:deletion_request) { DeletionRequest.create!(user: user, status: 0, requested_at: Time.current) }
        let(:id) { deletion_request.id }
        schema type: :object,
          properties: {
            success: { type: :boolean },
            message: { type: :string },
            deletion_request: {
              type: :object,
              properties: {
                id: { type: :integer },
                user_id: { type: :integer },
                user: {
                  type: :object,
                  properties: {
                    id: { type: :integer },
                    username: { type: :string },
                    display_name: { type: :string }
                  }
                },
                status: { type: :string, enum: %w[pending approved cancelled completed] },
                requested_at: { type: :string, format: :date_time },
                scheduled_deletion_at: { type: :string, format: :date_time, nullable: true },
                completed_at: { type: :string, format: :date_time, nullable: true },
                admin_approved_by: { type: :object, nullable: true },
                created_at: { type: :string, format: :date_time },
                updated_at: { type: :string, format: :date_time }
              }
            }
          }
        run_test!
      end
    end
  end
end
