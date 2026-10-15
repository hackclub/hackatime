require 'swagger_helper'

RSpec.describe 'Api::Openapi', type: :request do
  path '/openapi.json' do
    get('Fetch the OpenAPI description of this API') do
      tags 'Discovery'
      description <<~DESC
        Returns this document. No authentication is required.

        `/api/openapi.json` is an alias for the same resource, and the YAML
        representation is available at `/openapi.yaml` (aliased at
        `/api/openapi.yaml`).
      DESC
      security []
      produces 'application/json'

      response(200, 'successful') do
        schema type: :object,
          description: 'An OpenAPI 3.0 document describing the Hackatime API.',
          properties: {
            openapi: { type: :string, example: '3.0.1' },
            info: { type: :object },
            paths: { type: :object },
            components: { type: :object },
            servers: { type: :array, items: { type: :object } }
          },
          required: %w[openapi info paths]

        run_test! do |response|
          body = JSON.parse(response.body)
          expect(body['openapi']).to eq('3.0.1')
          expect(body.dig('info', 'title')).to eq('Hackatime API')
          expect(body['paths']).to be_a(Hash)
        end
      end
    end
  end

  path '/openapi.yaml' do
    get('Fetch the OpenAPI description of this API as YAML') do
      tags 'Discovery'
      description 'The YAML representation of `/openapi.json`. No authentication is required.'
      security []
      produces 'application/yaml'

      response(200, 'successful') do
        schema type: :string, description: 'An OpenAPI 3.0 document, serialised as YAML.'

        run_test! do |response|
          body = YAML.safe_load(response.body, aliases: true)
          expect(body['openapi']).to eq('3.0.1')
          expect(body.dig('info', 'title')).to eq('Hackatime API')
        end
      end
    end
  end
end
