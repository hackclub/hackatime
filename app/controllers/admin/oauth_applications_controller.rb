class Admin::OauthApplicationsController < Admin::BaseController
  before_action :set_application, only: [ :show, :edit, :update, :toggle_verified, :rotate_secret ]

  def index
    @applications = OauthApplication.includes(:owner).order(created_at: :desc)
    render inertia: "OAuthApplications/Index", props: {
      page_title: "All OAuth Applications - Admin",
      admin_mode: true,
      applications: @applications.map { |application| page_props(application).summary }
    }
  end

  def show
    render inertia: "OAuthApplications/Show", props: page_props.show(
      secret: flash[:application_secret].presence,
      can_toggle_verified: true
    )
  end

  def edit
    render inertia: "OAuthApplications/Edit", props: page_props.form(action: :edit)
  end

  def update
    if @application.admin_update(application_params)
      redirect_to admin_oauth_application_path(@application), notice: "updated successfully."
    else
      render inertia: "OAuthApplications/Edit", props: page_props.form(action: :edit), status: :unprocessable_entity
    end
  end

  def toggle_verified
    @application.update!(verified: !@application.verified?)
    redirect_back fallback_location: admin_oauth_application_path(@application),
                  notice: @application.verified? ? "gave them twitter blue!" : "took away twitter blue!"
  end

  def rotate_secret
    @application.renew_secret
    if @application.save
      flash[:notice] = I18n.t(:notice, scope: %i[doorkeeper flash applications rotate_secret])
      flash[:application_secret] = @application.plaintext_secret
    else
      flash[:alert] = I18n.t(:alert, scope: %i[doorkeeper flash applications rotate_secret])
    end
    redirect_to admin_oauth_application_path(@application)
  end

  private

  def set_application
    @application = OauthApplication.find(params[:id])
  end

  def application_params
    permitted = params.require(:oauth_application)
      .permit(:name, :redirect_uri, :confidential, :redirect_to_hca_login, scopes: [])
    permitted[:scopes] = Array(permitted[:scopes]).compact_blank.join(" ")
    permitted
  end

  def page_props(application = @application)
    OauthApplicationPageProps.new(application, admin_mode: true, actor: current_user, can_assign_admin_scope: true)
  end
end
