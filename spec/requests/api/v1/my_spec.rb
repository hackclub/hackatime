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
      description 'Returns the most recent heartbeat for the authenticated user. Useful for checking if the user is currently active. ' \
                  'Authenticate with your API key as a Bearer token in the `Authorization` header (HTTP Basic auth with the API key is also accepted).'
      security [ { Bearer: [] } ]
      produces 'application/json'

      parameter name: :source_type, in: :query, type: :string, description: 'Filter by source type (e.g. "direct_entry"). If omitted, results exclude heartbeats with source_type "test_entry" by default.'
      parameter name: :editor, in: :query, type: :string, description: 'Filter by editor name (e.g. "VSCode"). Matched case-insensitively.'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:source_type) { 'direct_entry' }
        let(:editor) { 'VSCode' }

        schema type: :object,
          properties: {
            has_heartbeat: { type: :boolean, description: 'Whether a matching heartbeat was found.', example: true },
            heartbeat: {
              type: :object,
              nullable: true,
              description: 'The most recent matching heartbeat, or null when none is found.'
            },
            editor: { type: :string, nullable: true, description: 'Editor of the matching heartbeat, or null.', example: 'VS Code' },
            time_ago: { type: :string, nullable: true, description: 'Human-readable time since the heartbeat (e.g. "5 minutes ago"), or null.', example: '5 minutes ago' }
          },
          required: [ 'has_heartbeat', 'heartbeat', 'editor', 'time_ago' ]
        run_test!
      end

      response(401, 'unauthorized — Returned when the Authorization header is missing or the token does not match a known API key.') do
        let(:Authorization) { 'Bearer invalid' }
        let(:source_type) { 'direct_entry' }
        let(:editor) { 'VSCode' }
        run_test!
      end
    end
  end

  path '/api/v1/my/heartbeats' do
    get('Get heartbeats') do
      tags 'My Data'
      description 'Returns a list of heartbeats for the authenticated user within a time range. This is the raw data stream. ' \
                  'Authenticate with your API key as a Bearer token in the `Authorization` header (HTTP Basic auth with the API key is also accepted).'
      security [ { Bearer: [] } ]
      produces 'application/json'

      parameter name: :start_time, in: :query, schema: { type: :string, format: :date_time }, description: 'Start time (ISO 8601). Defaults to the beginning of the current day when omitted.'
      parameter name: :end_time, in: :query, schema: { type: :string, format: :date_time }, description: 'End time (ISO 8601). Defaults to the end of the current day when omitted.'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:start_time) { 1.day.ago.iso8601 }
        let(:end_time) { Time.now.iso8601 }

        schema type: :object,
          properties: {
            start_time: { type: :string, format: :date_time, description: 'Effective start of the queried range.', example: '2024-03-20T00:00:00Z' },
            end_time: { type: :string, format: :date_time, description: 'Effective end of the queried range.', example: '2024-03-20T23:59:59Z' },
            total_seconds: { type: :number, description: 'Total coding duration in seconds across the returned heartbeats.', example: 3600.0 },
            heartbeats: {
              type: :array,
              description: 'Heartbeats in the range, ordered by time ascending.',
              items: { '$ref' => '#/components/schemas/Heartbeat' }
            }
          },
          required: [ 'start_time', 'end_time', 'total_seconds', 'heartbeats' ]
        run_test!
      end

      response(401, 'unauthorized — Returned when the Authorization header is missing or the token does not match a known API key.') do
        let(:Authorization) { 'Bearer invalid' }
        let(:start_time) { 1.day.ago.iso8601 }
        let(:end_time) { Time.now.iso8601 }
        run_test!
      end
    end
  end

  path '/my/heartbeats/export' do
    post('Export Heartbeats') do
      tags 'My Data'
      description 'Export your heartbeats as a JSON file.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :all_data, in: :query, type: :boolean, description: 'Export all data (true/false)'
      parameter name: :start_date, in: :query, schema: { type: :string, format: :date }, description: 'Start date (YYYY-MM-DD)'
      parameter name: :end_date, in: :query, schema: { type: :string, format: :date }, description: 'End date (YYYY-MM-DD)'

      response(302, 'redirect', document: false) do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }
        let(:all_data) { true }
        let(:start_date) { Date.today.to_s }
        let(:end_date) { Date.today.to_s }

        before { login_browser_user }
        run_test!
      end
    end
  end

  path '/my/heartbeat_imports' do
    post('Create Heartbeat Import') do
      tags 'My Data'
      description 'Start a development upload import or a one-time remote dump import.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      consumes 'multipart/form-data'
      produces 'application/json'

      parameter name: :"heartbeat_import[provider]",
                in: :formData,
                schema: { type: :string, enum: %w[wakatime_dump hackatime_v1_dump] },
                description: 'Remote import provider preset'
      parameter name: :"heartbeat_import[api_key]",
                in: :formData,
                schema: { type: :string },
                description: 'API key for the selected remote import provider'

      response(302, 'redirects to the imports page (errors are carried in flash)', document: false) do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }
        let(:"heartbeat_import[provider]") { "wakatime_dump" }
        let(:"heartbeat_import[api_key]") { "test-api-key" }

        before do
          login_browser_user
          Flipper.enable_actor(:imports, user)
        end
        after { Flipper.disable(:imports) }
        run_test!
      end
    end
  end

  path '/my/projects' do
    get('List Project Repo Mappings') do
      tags 'My Projects'
      description 'List mappings between local project names and Git repositories.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'text/html'

      parameter name: :interval, in: :query, type: :string, description: 'Time interval (e.g., daily, weekly). Default: daily'
      parameter name: :from, in: :query, schema: { type: :string, format: :date }, description: 'Start date (YYYY-MM-DD)'
      parameter name: :to, in: :query, schema: { type: :string, format: :date }, description: 'End date (YYYY-MM-DD)'
      response(200, 'successful', document: false) do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }
        let(:interval) { 'daily' }
        let(:from) { Date.today.to_s }
        let(:to) { Date.today.to_s }

        before { login_browser_user }
        run_test!
      end
    end
  end

  path '/my/project_repo_mappings/{project_name}' do
    parameter name: :project_name, in: :path, type: :string, description: 'Project name (encoded)'

    patch('Update Project Repo Mapping') do
      tags 'My Projects'
      description 'Update the Git repository URL for a project mapping.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :project_repo_mapping, in: :body, schema: {
        type: :object,
        properties: {
          repo_url: { type: :string, example: 'https://github.com/hackclub/hackatime' }
        },
        required: [ 'repo_url' ]
      }

      response(302, 'redirect', document: false) do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }
        let(:project_name) { 'hackatime' }
        let(:project_repo_mapping) { { repo_url: 'https://github.com/hackclub/hackatime' } }

        before do
          login_browser_user
          user.update(github_uid: '12345')
        end

        run_test!
      end
    end
  end

  path '/my/project_repo_mappings/{project_name}/archive' do
    parameter name: :project_name, in: :path, type: :string, description: 'Project name (encoded)'

    patch('Archive Project Mapping') do
      tags 'My Projects'
      description 'Archive a project mapping so it does not appear in active lists.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      response(302, 'redirect', document: false) do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }
        let(:project_name) { 'hackatime' }

        before do
           login_browser_user
           user.project_repo_mappings.create!(project_name: 'hackatime')
        end
        run_test!
      end
    end
  end

  path '/my/project_repo_mappings/{project_name}/unarchive' do
    parameter name: :project_name, in: :path, type: :string, description: 'Project name (encoded)'

    patch('Unarchive Project Mapping') do
      tags 'My Projects'
      description 'Restore an archived project mapping.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      response(302, 'redirect', document: false) do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }
        let(:project_name) { 'hackatime' }

        before do
           login_browser_user
           p = user.project_repo_mappings.create!(project_name: 'hackatime')
           p.archive!
        end
        run_test!
      end
    end
  end

  path '/my/settings/privacy/rotate_api_key' do
    post('Rotate API Key') do
      tags 'My Settings'
      description 'Rotate your API key and redirect back to the privacy settings page (the new token is shown there via flash). Warning: the old token stops working immediately.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'text/html'

      response(302, 'redirect', document: false) do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }

        before { login_browser_user }
        run_test!
      end
    end
  end

  path '/my/heartbeat_imports/{id}' do
    get('Get Heartbeat Import Status') do
      tags 'My Data'
      description 'Fetch the latest state for a heartbeat import run.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :id, in: :path, type: :string, description: 'Heartbeat import run id'

      response(200, 'successful', document: false) do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }
        let(:id) do
          HeartbeatImportRun.create!(
            user: user,
            source_kind: :dev_upload,
            state: :completed,
            source_filename: "heartbeats.json",
            message: "Completed."
          ).id
        end

        before { login_browser_user }
        run_test!
      end
    end
  end

  path '/deletion' do
    post('Create Deletion Request') do
      tags 'My Settings'
      description 'Request deletion of your account and data.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'text/html'

      response(302, 'redirect', document: false) do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }

        before { login_browser_user }
        run_test!
      end
    end

    delete('Cancel Deletion Request') do
      tags 'My Settings'
      description 'Cancel a pending deletion request.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'text/html'

      response(302, 'redirect', document: false) do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }

        before do
           login_browser_user
           DeletionRequest.create_for_user!(user)
        end
        run_test!
      end
    end
  end
end
