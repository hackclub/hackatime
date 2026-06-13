require 'swagger_helper'

RSpec.describe 'Api::V1::CurrentlyHacking', type: :request do
  path '/api/v1/currently_hacking' do
    get('List users currently hacking') do
      tags 'Currently Hacking'
      description <<~DESC
        Returns the set of users who have logged a direct-entry coding heartbeat
        in the last 5 minutes, along with the project each is currently working
        on (if its repo mapping is not archived). The endpoint is public (no
        authentication required) and the result is cached for 5 minutes.
      DESC
      produces 'application/json'

      response(200, 'successful') do
        schema type: :object,
          properties: {
            count: { type: :integer, description: 'Number of users currently hacking.', example: 1 },
            users: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  display_name: { type: :string, nullable: true, example: 'Orpheus' },
                  avatar_url: { type: :string, nullable: true, example: 'https://hackatime.hackclub.com/images/athena.png' },
                  country_code: { type: :string, nullable: true, example: 'US' },
                  working_on: {
                    type: :object,
                    nullable: true,
                    description: 'The project the user is currently working on, or null.',
                    properties: {
                      project_name: { type: :string, example: 'hackatime' },
                      repo_url: { type: :string, nullable: true, example: 'https://github.com/hackclub/hackatime' }
                    }
                  }
                },
                required: %w[display_name avatar_url country_code working_on]
              }
            }
          },
          required: %w[count users]

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body).to have_key('count')
          expect(body['users']).to be_an(Array)
        end
      end
    end
  end
end
