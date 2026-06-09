require 'swagger_helper'

RSpec.describe 'Api::Admin::V1::Heartbeats', type: :request, openapi_spec: 'admin/swagger.yaml' do
  def create_user(username, email)
    u = User.create!(username: username)
    EmailAddress.create!(user: u, email: email)
    u
  end

  def create_heartbeat(user, machine:, ip_address: nil)
    Heartbeat.create!(
      user: user,
      time: Time.current.to_i,
      project: 'test',
      language: 'Ruby',
      editor: 'VS Code',
      source_type: :direct_entry,
      branch: 'main',
      category: 'coding',
      is_write: false,
      operating_system: 'linux',
      machine: machine,
      ip_address: ip_address
    )
  end

  path '/api/admin/v1/heartbeats/ip_machine_pairs' do
    get('List users sharing the same machine + IP combination') do
      tags 'Admin Heartbeats'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :lookback_days, in: :query, type: :integer, required: false,
                description: 'Number of days to look back (default: 30, max: 365)'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Max results (default: 1000, max: 10000)'

      response(200, 'returns pairs of users sharing machine+IP') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_a) { create_user('ip_pair_user_a', 'ip_pair_a@example.com') }
        let(:user_b) { create_user('ip_pair_user_b', 'ip_pair_b@example.com') }
        let(:lookback_days) { 30 }
        let(:limit) { nil }

        before do
          create_heartbeat(user_a, machine: 'shared-box', ip_address: '1.2.3.4')
          create_heartbeat(user_b, machine: 'shared-box', ip_address: '1.2.3.4')
        end

        schema type: :object,
          properties: {
            pairs: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  user_a_id:        { type: :integer, example: 42 },
                  user_b_id:        { type: :integer, example: 43 },
                  machine:          { type: :string, example: 'Orpheus-MacBook-Pro' },
                  ip_address:       { type: :string, example: '203.0.113.7' },
                  user_a_first_seen: { type: :number, example: 1710340200.0, description: 'Unix timestamp (may be fractional)' },
                  user_a_last_seen:  { type: :number, example: 1710946200.0, description: 'Unix timestamp (may be fractional)' },
                  user_b_first_seen: { type: :number, example: 1710512400.0, description: 'Unix timestamp (may be fractional)' },
                  user_b_last_seen:  { type: :number, example: 1710859800.0, description: 'Unix timestamp (may be fractional)' }
                }
              }
            }
          }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['pairs']).to be_an(Array)
          pair = body['pairs'].find do |p|
            [ p['user_a_id'], p['user_b_id'] ].sort == [ user_a.id, user_b.id ].sort
          end
          expect(pair).not_to be_nil
          expect(pair['machine']).to eq('shared-box')
          expect(pair['ip_address']).to eq('1.2.3.4')
        end
      end

      response(200, 'returns empty pairs when no shared machine+IP exists') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_a) { create_user('no_pair_user_a', 'no_pair_a@example.com') }
        let(:user_b) { create_user('no_pair_user_b', 'no_pair_b@example.com') }
        let(:lookback_days) { 30 }
        let(:limit) { nil }

        before do
          create_heartbeat(user_a, machine: 'box-a', ip_address: '1.1.1.1')
          create_heartbeat(user_b, machine: 'box-b', ip_address: '2.2.2.2')
        end

        schema type: :object,
          properties: { pairs: { type: :array, items: { type: :object } } }

        run_test! do |response|
          body = JSON.parse(response.body)
          ids = body['pairs'].flat_map { |p| [ p['user_a_id'], p['user_b_id'] ] }
          expect(ids).not_to include(user_a.id, user_b.id)
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-admin-key" }
        let(:lookback_days) { 30 }
        let(:limit) { nil }
        run_test!
      end
    end
  end

  path '/api/admin/v1/heartbeats/shared_machines' do
    get('List machines used by multiple users') do
      tags 'Admin Heartbeats'
      security [ AdminToken: [] ]
      produces 'application/json'

      parameter name: :lookback_days, in: :query, type: :integer, required: false,
                description: 'Number of days to look back (default: 30, max: 365)'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Max results (default: 1000, max: 10000)'

      response(200, 'returns machines shared by multiple users') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:user_a) { create_user('sm_user_a', 'sm_a@example.com') }
        let(:user_b) { create_user('sm_user_b', 'sm_b@example.com') }
        let(:lookback_days) { 30 }
        let(:limit) { nil }

        before do
          create_heartbeat(user_a, machine: 'shared-machine')
          create_heartbeat(user_b, machine: 'shared-machine')
        end

        schema type: :object,
          properties: {
            machines: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  machine:           { type: :string, example: 'Orpheus-MacBook-Pro' },
                  machine_frequency: { type: :integer, example: 2 },
                  user_ids:          { type: :string, example: '{42,43}', description: 'PostgreSQL array literal of user IDs (raw ARRAY_AGG output, not a JSON array)' }
                }
              }
            }
          }

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['machines']).to be_an(Array)
          entry = body['machines'].find { |m| m['machine'] == 'shared-machine' }
          expect(entry).not_to be_nil
          expect(entry['machine_frequency']).to eq(2)
          ids = entry['user_ids'].delete('{}').split(',').map(&:to_i)
          expect(ids).to match_array([ user_a.id, user_b.id ])
        end
      end

      response(200, 'excludes machines used by only one user') do
        let(:Authorization) { "Bearer dev-admin-api-key-12345" }
        let(:solo_user) { create_user('sm_solo_user', 'sm_solo@example.com') }
        let(:lookback_days) { 30 }
        let(:limit) { nil }

        before { create_heartbeat(solo_user, machine: 'solo-machine') }

        schema type: :object,
          properties: { machines: { type: :array, items: { type: :object } } }

        run_test! do |response|
          body = JSON.parse(response.body)
          machines = body['machines'].map { |m| m['machine'] }
          expect(machines).not_to include('solo-machine')
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { "Bearer invalid-admin-key" }
        let(:lookback_days) { 30 }
        let(:limit) { nil }
        run_test!
      end
    end
  end
end
