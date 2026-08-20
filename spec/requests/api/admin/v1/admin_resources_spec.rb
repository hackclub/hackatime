require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::Resources', type: :request, openapi_spec: 'admin/swagger.yaml' do
  deletion_request_schema = {
    type: :object,
    properties: {
      id: { type: :integer, example: 7 },
      user_id: { type: :integer, example: 42 },
      user: {
        type: :object,
        nullable: true,
        properties: {
          id: { type: :integer, example: 42 },
          username: { type: :string, example: 'orpheus' },
          display_name: { type: :string, nullable: true, example: 'orpheus' }
        }
      },
      status: { type: :string, enum: %w[pending approved cancelled completed], example: 'pending' },
      requested_at: { type: :string, format: :date_time, nullable: true, example: '2024-03-20T15:30:00Z' },
      scheduled_deletion_at: { type: :string, format: :date_time, nullable: true, example: '2024-03-27T15:30:00Z' },
      completed_at: { type: :string, format: :date_time, nullable: true, example: '2024-03-28T09:00:00Z' },
      admin_approved_by: {
        type: :object,
        nullable: true,
        properties: {
          id: { type: :integer, example: 1 },
          username: { type: :string, example: 'orpheus' },
          display_name: { type: :string, nullable: true, example: 'orpheus' }
        }
      },
      created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
      updated_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' }
    }
  }

  error_schema = {
    type: :object,
    properties: { error: { type: :string, example: 'Not found' } }
  }

  error_with_details_schema = {
    type: :object,
    properties: {
      error: { type: :string, example: 'Validation failed' },
      errors: { type: :array, items: { type: :string, example: "Name can't be blank" } }
    }
  }

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
                  id: { type: :integer, example: 12 },
                  name: { type: :string, example: 'Revoker admin key' },
                  token_preview: { type: :string, example: 'hka_3f8e...7f01' },
                  user: {
                    type: :object,
                    properties: {
                      id: { type: :integer, example: 1 },
                      username: { type: :string, example: 'orpheus' },
                      display_name: { type: :string, example: 'orpheus' },
                      admin_level: { type: :string, example: 'superadmin' }
                    }
                  },
                  created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
                  revoked_at: { type: :string, format: :date_time, nullable: true, example: '2024-04-01T12:00:00Z' },
                  active: { type: :boolean, example: true }
                }
              }
            }
          }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
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
          name: { type: :string, example: 'Revoker admin key' }
        }
      }

      response(201, 'created') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { name: 'New Key' } }
        schema type: :object,
          properties: {
            success: { type: :boolean, example: true },
            message: { type: :string, example: 'Admin API key created successfully' },
            admin_api_key: {
              type: :object,
              properties: {
                id: { type: :integer, example: 12 },
                name: { type: :string, example: 'Revoker admin key' },
                token: { type: :string, example: 'hka_3f8e9c2a7b144d6e9a2f1c8b5d3e7f013f8e9c2a7b144d6e9a2f1c8b5d3e7f01' },
                created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' }
              }
            }
          }
        run_test!
      end

      response(422, 'validation failed') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:payload) { { name: '' } }
        schema(**error_with_details_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:payload) { { name: 'New Key' } }
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
            id: { type: :integer, example: 12 },
            name: { type: :string, example: 'Revoker admin key' },
            token_preview: { type: :string, example: 'hka_3f8e...7f01' },
            user: {
              type: :object,
              properties: {
                id: { type: :integer, example: 1 },
                username: { type: :string, example: 'orpheus' },
                display_name: { type: :string, example: 'orpheus' },
                admin_level: { type: :string, example: 'superadmin' }
              }
            },
            created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
            revoked_at: { type: :string, format: :date_time, nullable: true, example: '2024-04-01T12:00:00Z' },
            active: { type: :boolean, example: true }
          }
        run_test!
      end

      response(404, 'not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:id) { '0' }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:id) { '1' }
        run_test!
      end
    end

    delete('Revoke Admin API Key') do
      tags 'Admin Resources'
      description 'Revoke/Delete an admin API key. Ultraadmins may revoke any key, and other admins may only revoke their own.'
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:api_key_to_revoke) do
          AdminApiKey.find_by!(token: 'dev-admin-api-key-12345').user.admin_api_keys.create!(name: 'Revoke Key')
        end
        let(:id) { api_key_to_revoke.id }
        schema type: :object,
          properties: {
            success: { type: :boolean, example: true },
            message: { type: :string, example: 'Admin API key revoked successfully' }
          }
        run_test!
      end

      response(403, 'forbidden (not your key)') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:other_users_key) do
          u = User.create!(username: 'other_key_owner')
          EmailAddress.create!(user: u, email: 'other_key_owner@example.com')
          AdminApiKey.create!(user: u, name: 'Not Mine')
        end
        let(:id) { other_users_key.id }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:id) { '1' }
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
      parameter name: :trust_level_filter, in: :query, schema: { type: :string, enum: %w[to_convicted to_trusted to_suspected to_unscored] }, description: 'Filter by trust level change. Any unrecognized value (or omitting the parameter) returns all logs unfiltered.', required: false

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
                  id: { type: :integer, example: 5012 },
                  user: {
                    type: :object,
                    properties: {
                      id: { type: :integer, example: 42 },
                      username: { type: :string, example: 'orpheus' },
                      display_name: { type: :string, example: 'orpheus' }
                    }
                  },
                  previous_trust_level: { type: :string, nullable: true, example: 'blue' },
                  new_trust_level: { type: :string, nullable: true, example: 'red' },
                  changed_by: {
                    type: :object,
                    properties: {
                      id: { type: :integer, example: 1 },
                      username: { type: :string, example: 'orpheus' },
                      display_name: { type: :string, example: 'orpheus' },
                      admin_level: { type: :string, example: 'superadmin' }
                    }
                  },
                  reason: { type: :string, nullable: true, example: 'self-reported heartbeats' },
                  notes: { type: :string, nullable: true, example: 'Reviewed flagged activity' },
                  created_at: { type: :string, example: '2024-03-20T15:30:00Z' }
                }
              }
            },
            total_count: { type: :integer, example: 137 }
          }
        run_test!
      end

      response(404, 'user not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_id) { '0' }
        let(:admin_id) { nil }
        let(:user_search) { nil }
        let(:admin_search) { nil }
        let(:trust_level_filter) { nil }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:user_id) { nil }
        let(:admin_id) { nil }
        let(:user_search) { nil }
        let(:admin_search) { nil }
        let(:trust_level_filter) { nil }
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
            id: { type: :integer, example: 5012 },
            user: {
              type: :object,
              properties: {
                id: { type: :integer, example: 42 },
                username: { type: :string, example: 'orpheus' },
                display_name: { type: :string, example: 'orpheus' },
                current_trust_level: { type: :string, example: 'green' }
              }
            },
            previous_trust_level: { type: :string, nullable: true, example: 'blue' },
            new_trust_level: { type: :string, nullable: true, example: 'green' },
            changed_by: {
              type: :object,
              properties: {
                id: { type: :integer, example: 1 },
                username: { type: :string, example: 'orpheus' },
                display_name: { type: :string, example: 'orpheus' },
                admin_level: { type: :string, example: 'superadmin' }
              }
            },
            reason: { type: :string, nullable: true, example: 'Manual verification' },
            notes: { type: :string, nullable: true, example: 'Looks good' },
            created_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' },
            updated_at: { type: :string, format: :date_time, example: '2024-03-20T15:30:00Z' }
          }
        run_test!
      end

      response(404, 'not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:id) { '0' }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:id) { '1' }
        run_test!
      end
    end
  end

  path '/api/admin/v1/deletion_requests' do
    get('List Deletion Requests') do
      tags 'Admin Resources'
      description 'List pending, approved, and recently completed deletion requests. Requires superadmin privileges.'
      security [ AdminToken: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        schema type: :object,
          properties: {
            pending: { type: :array, items: deletion_request_schema },
            approved: { type: :array, items: deletion_request_schema },
            completed: { type: :array, items: deletion_request_schema }
          }
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        run_test!
      end
    end
  end

  path '/api/admin/v1/deletion_requests/{id}' do
    parameter name: :id, in: :path, type: :string

    get('Show Deletion Request') do
      tags 'Admin Resources'
      description 'Show details of a deletion request. Requires superadmin privileges.'
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
        schema(**deletion_request_schema)
        run_test!
      end

      response(404, 'not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:id) { '0' }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:id) { '1' }
        run_test!
      end
    end
  end

  path '/api/admin/v1/deletion_requests/{id}/approve' do
    post('Approve Deletion Request') do
      tags 'Admin Resources'
      description 'Approve and execute a user deletion request. Requires superadmin privileges.'
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
            success: { type: :boolean, example: true },
            message: { type: :string, example: 'Deletion request approved and processed' },
            deletion_request: deletion_request_schema
          }
        run_test!
      end

      response(404, 'not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:id) { '0' }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:id) { '1' }
        run_test!
      end
    end
  end

  path '/api/admin/v1/deletion_requests/{id}/reject' do
    post('Reject Deletion Request') do
      tags 'Admin Resources'
      description 'Reject a user deletion request. Requires superadmin privileges.'
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
            success: { type: :boolean, example: true },
            message: { type: :string, example: 'Deletion request rejected' },
            deletion_request: deletion_request_schema
          }
        run_test!
      end

      response(404, 'not found') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:id) { '0' }
        schema(**error_schema)
        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-token" }
        let(:id) { '1' }
        run_test!
      end
    end
  end
end
