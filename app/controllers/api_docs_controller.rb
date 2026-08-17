class ApiDocsController < ApplicationController
  layout "inertia"

  def show = render_docs("Hackatime API", "/api-docs/v1/swagger.yaml")
  def admin = render_docs("Hackatime Admin API", "/api-docs/admin/swagger.yaml")

  private

  def render_docs(title, spec_url)
    render inertia: "ApiDocs/Show", props: { title: title, spec_url: spec_url }
  end
end
