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
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(user)
  end

  path '/api/v1/my/heartbeats/most_recent' do
    get('Get most recent heartbeat') do
      tags 'My Data'
      description 'Returns the most recent heartbeat for the authenticated user. Useful for checking if the user is currently active.'
      security [ Bearer: [], ApiKeyAuth: [] ]
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
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :start_time, in: :query, type: :string, format: :date_time, description: 'Start time (ISO 8601)'
      parameter name: :end_time, in: :query, type: :string, format: :date_time, description: 'End time (ISO 8601)'

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

  path '/my/heartbeats/export' do
    get('Export Heartbeats') do
      tags 'My Data'
      description 'Export your heartbeats as a JSON file.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      parameter name: :all_data, in: :query, type: :boolean, description: 'Export all data (true/false)'
      parameter name: :start_date, in: :query, type: :string, format: :date, description: 'Start date (YYYY-MM-DD)'
      parameter name: :end_date, in: :query, type: :string, format: :date, description: 'End date (YYYY-MM-DD)'

      response(200, 'successful') do
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

  path '/my/heartbeats/import' do
    post('Import Heartbeats') do
      tags 'My Data'
      description 'Import heartbeats from a JSON file.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      consumes 'multipart/form-data'
      produces 'application/json'

      parameter name: :heartbeat_file, in: :formData, type: :file, description: 'JSON file containing heartbeats'

      response(302, 'redirect') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }
        let(:heartbeat_file) { Rack::Test::UploadedFile.new(Rails.root.join('spec/fixtures/heartbeats.json'), 'application/json') }

        before do
           FileUtils.mkdir_p(Rails.root.join('spec/fixtures'))
           File.write(Rails.root.join('spec/fixtures/heartbeats.json'), '[]') unless File.exist?(Rails.root.join('spec/fixtures/heartbeats.json'))
           login_browser_user
        end
        run_test!
      end
    end
  end

  path '/my/projects' do
    get('List Project Repo Mappings') do
      tags 'My Projects'
      description 'List mappings between local project names and Git repositories.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json', 'text/html'

      parameter name: :interval, in: :query, type: :string, description: 'Time interval (e.g., daily, weekly). Default: daily'
      parameter name: :from, in: :query, type: :string, format: :date, description: 'Start date (YYYY-MM-DD)'
      parameter name: :to, in: :query, type: :string, format: :date, description: 'End date (YYYY-MM-DD)'
      response(200, 'successful') do
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

      response(302, 'redirect') do
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

      response(302, 'redirect') do
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

      response(302, 'redirect') do
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

  path '/my/settings/rotate_api_key' do
    post('Rotate API Key') do
      tags 'My Settings'
      description 'Rotate your API key. Returns the new token. Warning: Old token will stop working immediately.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      response(200, 'successful') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }

        before { login_browser_user }
        run_test!
      end
    end
  end

  path '/my/settings/migrate_heartbeats' do
    post('Migrate Heartbeats') do
      tags 'My Settings'
      description 'Trigger a migration of heartbeats from legacy formats or systems.'
      security [ Bearer: [], ApiKeyAuth: [] ]
      produces 'application/json'

      response(302, 'redirect') do
        let(:Authorization) { "Bearer dev-api-key-12345" }
        let(:api_key) { 'dev-api-key-12345' }

        before do
          login_browser_user
          allow(MigrateUserFromHackatimeJob).to receive(:perform_later)
        end
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

      response(302, 'redirect') do
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

      response(302, 'redirect') do
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
