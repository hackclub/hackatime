require 'swagger_helper'

RSpec.describe 'Api::V1::Public', type: :request do
  path '/api/v1/currently_hacking' do
    get('List users currently hacking') do
      tags 'Public'
      description 'Returns users with recent coding activity.'
      produces 'application/json'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            count: { type: :integer },
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  display_name: { type: :string, nullable: true },
                  avatar_url: { type: :string, nullable: true },
                  country_code: { type: :string, nullable: true },
                  working_on: {
                    type: :object,
                    nullable: true,
                    properties: {
                      project_name: { type: :string },
                      repo_url: { type: :string, nullable: true }
                    }
                  }
                }
              }
            }
          }

        run_test!
      end
    end
  end

  path '/api/v1/banned_users/counts' do
    get('Get banned user counts') do
      tags 'Stats'
      description 'Returns distinct red trust-level user counts over the last day, week, and month.'
      produces 'application/json'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            day: { type: :integer },
            week: { type: :integer },
            month: { type: :integer }
          }

        run_test!
      end
    end
  end

  path '/api/v1/badge/{user_id}/{project}' do
    get('Get project coding-time badge') do
      tags 'Badges'
      description 'Redirects to a shields.io badge for a user project.'
      produces 'image/svg+xml'

      parameter name: :user_id, in: :path, type: :string, description: 'Slack UID, username, or internal user ID'
      parameter name: :project, in: :path, type: :string, description: 'Project name or owner/repo'
      parameter name: :label, in: :query, type: :string, required: false, description: 'Badge label'
      parameter name: :color, in: :query, type: :string, required: false, description: 'Badge color'
      parameter name: :aliases, in: :query, type: :string, required: false, description: 'Comma-separated extra project names to include'

      response(307, 'temporary redirect') do
        let(:badge_user) { User.create!(username: "badge_user_#{SecureRandom.hex(4)}", allow_public_stats_lookup: true) }
        let(:user_id) { badge_user.username }
        let(:project) { 'hackatime' }
        let(:label) { nil }
        let(:color) { nil }
        let(:aliases) { nil }

        before do
          now = Time.current.to_f
          [ now, now + 60 ].each do |time|
            Heartbeat.create!(
              user: badge_user,
              time: time,
              project: project,
              category: 'coding',
              source_type: :direct_entry
            )
          end
        end

        run_test!
      end
    end
  end
end
