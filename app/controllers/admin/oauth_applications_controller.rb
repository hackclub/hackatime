class Admin::OauthApplicationsController < Admin::BaseController
  before_action :authenticate_superadmin!
  before_action :set_application, only: [ :show, :edit, :update, :toggle_verified ]

  def index
    @applications = OauthApplication.includes(:owner).order(created_at: :desc)
  end

  def show
  end

  def edit
  end

  def update
    @application.admin_bypass = true
    if @application.update(application_params)
      redirect_to admin_oauth_application_path(@application), notice: "updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_verified
    @application.update!(verified: !@application.verified?)
    redirect_back fallback_location: admin_oauth_application_path(@application),
                  notice: @application.verified? ? "gave them twitter blue!" : "took away twitter blue!"
  end

  private

  def authenticate_superadmin!
    unless current_user&.admin_level_superadmin?
      redirect_to root_path, alert: "Forbidden"
    end
  end

  def set_application
    @application = OauthApplication.find(params[:id])
  end

  def application_params
    params.require(:oauth_application).permit(:name, :redirect_uri, :scopes, :confidential)
  end
end
