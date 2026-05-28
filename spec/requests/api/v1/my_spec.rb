require 'swagger_helper'

RSpec.describe 'Api::V1::My', type: :request do
  let(:user) do
    User.find_by(slack_uid: 'TEST123456') || User.create!(
      slack_uid: 'TEST123456',
      username: 'testuser',
      slack_username: 'testuser',
      timezone: 'America/New_York'
    )
  end

  def login_browser_user
    allow_any_instance_of(ActionController::Base).to receive(:protect_against_forgery?).and_return(false)
    sign_in_token = user.sign_in_tokens.create!(auth_type: :email)
    get "/auth/token/#{sign_in_token.token}"
  end

  path '/api/v1/my/heartbeats/most_recent' do
    get('Get most recent heartbeat') do
      tags 'My Data'
      description 'Returns the most recent heartbeat for the authenticated user. Useful for checking if the user is currently active.'
      security [ { Bearer: [] }, { BasicApiKey: [] } ]
      produces 'application/json'

      parameter name: :source_type, in: :query, type: :string, description: 'Filter by source type (e.g. "direct_entry")'
      parameter name: :editor, in: :query, type: :string, description: 'Filter by editor name (e.g. "VSCode")'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }
        let(:source_type) { 'direct_entry' }
        let(:editor) { 'VSCode' }

        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { 'invalid' }
        let(:source_type) { 'direct_entry' }
        let(:editor) { 'VSCode' }
        run_test!
      end
    end
  end

  path '/api/v1/my/heartbeats' do
    get('Get heartbeats') do
      tags 'My Data'
      description 'Returns a list of heartbeats for the authenticated user within a time range. This is the raw data stream.'
      security [ { Bearer: [] }, { BasicApiKey: [] } ]
      produces 'application/json'

      parameter name: :start_time, in: :query, schema: { type: :string, format: :date_time }, description: 'Start time (ISO 8601)'
      parameter name: :end_time, in: :query, schema: { type: :string, format: :date_time }, description: 'End time (ISO 8601)'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }
        let(:start_time) { 1.day.ago.iso8601 }
        let(:end_time) { Time.now.iso8601 }

        run_test!
      end

      response(401, 'unauthorized') do
        let(:Authorization) { 'Bearer invalid' }
        let(:api_key) { 'invalid' }
        let(:start_time) { 1.day.ago.iso8601 }
        let(:end_time) { Time.now.iso8601 }
        run_test!
      end
    end
  end
end
