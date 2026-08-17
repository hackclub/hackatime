class Admin::OauthApplicationsController < Admin::BaseController
  before_action :set_application, only: [ :show, :edit, :update, :toggle_verified, :rotate_secret ]

  def index
    @applications = OauthApplication.includes(:owner).order(created_at: :desc)
    render inertia: "Admin/OAuthApplications/Index", props: {
      applications: @applications.map { |application| summary(application) }
    }
  end

  def show
    render inertia: "Admin/OAuthApplications/Show", props: show_props
  end

  def edit
    render inertia: "Admin/OAuthApplications/Edit", props: edit_props
  end

  def update
    if @application.admin_update(application_params)
      redirect_to admin_oauth_application_path(@application), notice: "updated successfully."
    else
      render inertia: "Admin/OAuthApplications/Edit", props: edit_props, status: :unprocessable_entity
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
    params.require(:oauth_application).permit(:name, :redirect_uri, :scopes, :confidential, :redirect_to_hca_login)
  end

  def summary(application)
    owner = application.owner
    { id: application.id, name: application.name, verified: application.verified?,
      redirect_uris: application.redirect_uri.to_s.split, created_at: application.created_at.strftime("%b %d, %Y"),
      owner: owner && { username: owner.username, display_name: owner.display_name, id: owner.id } }
  end

  def show_props
    owner = @application.owner
    { application: summary(@application).merge(uid: @application.uid, scopes: @application.scopes.to_a.map(&:to_s),
        confidential: @application.confidential?, redirect_to_hca_login: @application.redirect_to_hca_login?,
        created_at: @application.created_at.strftime("%B %d, %Y at %I:%M %p"),
        owner: owner && { id: owner.id, display_name: owner.display_name, avatar_url: owner.avatar_url,
                          can_impersonate: current_user.can_impersonate?(owner) }),
      secret: flash[:application_secret].presence }
  end

  def edit_props
    { application: { id: @application.id, name: @application.name.to_s, redirect_uri: @application.redirect_uri.to_s,
        scopes: @application.scopes.to_s, confidential: @application.confidential?,
        redirect_to_hca_login: @application.redirect_to_hca_login?, verified: @application.verified? },
      errors: @application.errors.to_hash }
  end
end
