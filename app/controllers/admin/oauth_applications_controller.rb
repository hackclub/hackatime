class Admin::OauthApplicationsController < Admin::BaseController
  before_action :set_application, only: [ :show, :edit, :update, :toggle_verified, :rotate_secret ]

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

  def rotate_secret
    unless current_user&.admin_level_superadmin?
      redirect_to admin_oauth_application_path(@application), alert: "Only superadmins can rotate secrets."
      return
    end

    @application.renew_secret
    if @application.save
      flash[:notice] = "Secret rotated successfully. Make sure to copy the secret!"
      flash[:application_secret] = @application.plaintext_secret
    else
      flash[:alert] = "Failed to rotate client secret. Please try again."
    end
    redirect_to admin_oauth_application_path(@application)
  end

  private

  def set_application
    @application = OauthApplication.find(params[:id])
  end

  def application_params
    params.require(:oauth_application).permit(:name, :redirect_uri, :scopes, :confidential)
  end
end
