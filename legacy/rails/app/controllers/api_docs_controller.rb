class ApiDocsController < ApplicationController
  def show
    render :show, layout: false, locals: { title: "Hackatime API", spec_url: "/api-docs/v1/swagger.yaml" }
  end

  def admin
    render :show, layout: false, locals: { title: "Hackatime Admin API", spec_url: "/api-docs/admin/swagger.yaml" }
  end
end
