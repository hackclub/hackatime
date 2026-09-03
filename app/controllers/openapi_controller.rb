# Publishes the OpenAPI description of Hackatime's public API at the
# conventional, machine-discoverable URLs (`/openapi.json`, `/openapi.yaml`
# and their `/api` aliases). The Scalar reference at `/api-docs` is the human
# entry point; these endpoints are what API clients, SDK generators and agents
# fetch. Both formats render the same document that `rswag` generates into
# `swagger/v1/swagger.yaml`, so there is a single source of truth.
class OpenapiController < ApplicationController
  SPEC_PATH = Rails.root.join("swagger", "v1", "swagger.yaml").freeze
  CACHE_MAX_AGE = 1.hour

  class << self
    def json_document
      @json_document ||= "#{JSON.pretty_generate(parsed_document)}\n"
    end

    def yaml_document
      @yaml_document ||= SPEC_PATH.read
    end

    private

    def parsed_document
      YAML.safe_load(yaml_document, aliases: true)
    end
  end

  def show_json
    render_spec self.class.json_document, "application/json"
  end

  def show_yaml
    # RFC 9512 registers `application/yaml` as the media type for YAML.
    render_spec self.class.yaml_document, "application/yaml"
  end

  private

  def render_spec(body, content_type)
    # Overrides ApplicationController's `no-store` default: the document is
    # public, identical for every caller and only changes on deploy.
    response.headers["Cache-Control"] = "public, max-age=#{CACHE_MAX_AGE.to_i}"
    # Browser-based API consoles need to fetch the spec cross-origin.
    response.headers["Access-Control-Allow-Origin"] = "*"

    render plain: body, content_type: content_type
  end
end
