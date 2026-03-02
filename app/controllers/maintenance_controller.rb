class MaintenanceController < ApplicationController
  skip_before_action :enforce_lockout

  def show
    render file: Rails.root.join("public", "maintenance.html"), layout: false, content_type: "text/html"
  end
end
