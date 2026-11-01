class ApiDocsController < ApplicationController
  layout "inertia"

  def show = render_docs(:api_docs, "/api-docs/v1/swagger.yaml")
  def admin = render_docs(:admin_api_docs, "/api-docs/admin/swagger.yaml")

  private

  def render_docs(og_page, spec_url)
    use_og_page(og_page)
    render inertia: "ApiDocs/Show", props: { title: @page_title, spec_url: spec_url }
  end
end
