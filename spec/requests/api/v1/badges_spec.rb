require 'swagger_helper'

RSpec.describe 'Api::V1::Badges', type: :request do
  def create_heartbeat(user, project, time)
    Heartbeat.create!(
      user: user,
      time: time,
      project: project,
      language: 'Ruby',
      editor: 'VS Code',
      source_type: :direct_entry,
      branch: 'main',
      category: 'coding',
      is_write: false,
      operating_system: 'linux',
      machine: 'badge-machine'
    )
  end

  # Two heartbeats a few minutes apart so duration_seconds > 0 (the first
  # heartbeat in a series contributes 0 because LAG(time) is NULL).
  def log_time(user, project, seconds: 600)
    base = Time.current.to_i - seconds
    create_heartbeat(user, project, base)
    create_heartbeat(user, project, base + seconds)
  end

  path '/api/v1/badge/{user_id}/{project}' do
    get('Generate a shields.io coding-time badge for a project') do
      tags 'Badges'
      description <<~DESC
        Redirects (307) to an img.shields.io badge URL showing the total coding
        time a user has logged on a project. The endpoint is public (no auth) but
        only works for users who have not disabled public stats lookup.

        `user_id` is matched, in order, against the user's Slack UID, then
        username, then (only when the value is all digits) the internal numeric
        ID. `project` may be a raw project name (e.g. `hackatime`) or an
        `owner/repo` pair (e.g. `hackclub/hackatime`) which is resolved to a
        project name via the user's repo mappings.

        Any additional query parameters not consumed below (e.g. `style`, `logo`,
        `logoColor`, `labelColor`) are passed straight through to shields.io.
      DESC

      parameter name: :user_id, in: :path, type: :string, required: true,
                description: 'User identifier: Slack UID, username, or numeric internal ID.'
      parameter name: :project, in: :path, type: :string, required: true,
                description: 'Project name (e.g. "hackatime") or "owner/repo" (e.g. "hackclub/hackatime").'
      parameter name: :label, in: :query, type: :string, required: false,
                description: 'Left-hand text of the badge. Default: "hackatime".'
      parameter name: :color, in: :query, type: :string, required: false,
                description: 'Badge color passed to shields.io (any shields.io-accepted color). Default: "blue".'
      parameter name: :aliases, in: :query, type: :string, required: false,
                description: 'Comma-separated list of additional project names whose coding time is summed into the total.'

      # img.shields.io is an external host; the test issues a real redirect, so
      # stub it out to avoid net connections (WebMock is enabled).
      before do
        stub_request(:get, /img\.shields\.io/).to_return(status: 200, body: '<svg/>', headers: { 'Content-Type' => 'image/svg+xml' })
      end

      response(307, 'redirect to the shields.io badge image') do
        let(:badge_user) do
          User.create!(slack_uid: "UBADGE#{SecureRandom.hex(4)}", timezone: 'UTC', allow_public_stats_lookup: true)
        end
        let(:user_id) { badge_user.slack_uid }
        let(:project) { 'hackatime' }
        let(:label) { nil }
        let(:color) { nil }
        let(:aliases) { nil }

        before { log_time(badge_user, 'hackatime') }

        run_test! do |response|
          expect(response.status).to eq(307)
          expect(response.headers['Location']).to start_with('https://img.shields.io/badge/')
        end
      end

      response(404, 'user not found') do
        let(:user_id) { 'definitely-no-such-user' }
        let(:project) { 'hackatime' }
        let(:label) { nil }
        let(:color) { nil }
        let(:aliases) { nil }

        schema '$ref' => '#/components/schemas/Error'
        run_test! do |response|
          expect(JSON.parse(response.body)['error']).to eq('User not found')
        end
      end

      response(403, 'user has disabled public stats lookup') do
        let(:badge_user) do
          User.create!(slack_uid: "UPRIV#{SecureRandom.hex(4)}", timezone: 'UTC', allow_public_stats_lookup: false)
        end
        let(:user_id) { badge_user.slack_uid }
        let(:project) { 'hackatime' }
        let(:label) { nil }
        let(:color) { nil }
        let(:aliases) { nil }

        schema '$ref' => '#/components/schemas/Error'
        run_test! do |response|
          expect(JSON.parse(response.body)['error']).to eq('User has disabled public stats')
        end
      end

      response(404, 'project not found') do
        let(:badge_user) do
          User.create!(slack_uid: "UNOPROJ#{SecureRandom.hex(4)}", timezone: 'UTC', allow_public_stats_lookup: true)
        end
        let(:user_id) { badge_user.slack_uid }
        let(:project) { 'a-project-with-no-heartbeats' }
        let(:label) { nil }
        let(:color) { nil }
        let(:aliases) { nil }

        schema '$ref' => '#/components/schemas/Error'
        run_test! do |response|
          expect(JSON.parse(response.body)['error']).to eq('Project not found')
        end
      end

      response(400, 'project has no countable coding time') do
        # A single heartbeat resolves the project name (so it isn't a 404) but
        # yields duration_seconds == 0, triggering `head :bad_request`.
        let(:badge_user) do
          User.create!(slack_uid: "UZERO#{SecureRandom.hex(4)}", timezone: 'UTC', allow_public_stats_lookup: true)
        end
        let(:user_id) { badge_user.slack_uid }
        let(:project) { 'hackatime' }
        let(:label) { nil }
        let(:color) { nil }
        let(:aliases) { nil }

        before { create_heartbeat(badge_user, 'hackatime', Time.current.to_i) }

        run_test! do |response|
          expect(response.status).to eq(400)
        end
      end
    end
  end
end
