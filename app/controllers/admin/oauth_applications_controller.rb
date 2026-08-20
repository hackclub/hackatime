class Admin::OauthApplicationsController < Admin::BaseController
  before_action :set_application, only: [ :show, :edit, :update, :toggle_verified, :rotate_secret ]

  def index
    @applications = OauthApplication.includes(:owner).order(created_at: :desc)
    render inertia: "OAuthApplications/Index", props: {
      page_title: "All OAuth Applications - Admin",
      admin_mode: true,
      applications: @applications.map { |application| summary(application) }
    }
  end

  def show
    render inertia: "OAuthApplications/Show", props: show_props
  end

  def edit
    render inertia: "OAuthApplications/Edit", props: edit_props
  end

  def update
    if @application.admin_update(application_params)
      redirect_to admin_oauth_application_path(@application), notice: "updated successfully."
    else
      render inertia: "OAuthApplications/Edit", props: edit_props, status: :unprocessable_entity
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

  def summary(application)
    owner = application.owner
    { id: application.id, name: application.name, verified: application.verified?,
      confidential: application.confidential?, scopes: application.scopes.to_a.map(&:to_s),
      redirect_uris: application.redirect_uri.to_s.split, created_at: application.created_at.strftime("%b %d, %Y"),
      owner: owner && { id: owner.id, display_name: owner.display_name } }
  end

  def show_props
    owner = @application.owner
    secret = flash[:application_secret].presence
    { page_title: "#{@application.name} - Admin OAuth Application",
      heading: @application.name,
      subheading: "Admin view of OAuth application credentials and settings.",
      admin_mode: true,
      application: summary(@application).merge(uid: @application.uid,
        redirect_to_hca_login: @application.redirect_to_hca_login?, can_toggle_verified: true,
        created_at: @application.created_at.strftime("%B %d, %Y at %I:%M %p"),
        owner: owner && { id: owner.id, display_name: owner.display_name, avatar_url: owner.avatar_url,
                          can_impersonate: current_user.can_impersonate?(owner) }),
      secret: { value: secret, hashed: secret.blank? && Doorkeeper.config.application_secret_hashed?,
                just_rotated: secret.present? },
      labels: show_labels,
      confirmations: {
        rotate_secret: "Are you sure? This will invalidate the current client secret and break existing integrations."
      } }
  end

  def edit_props
    { page_title: "Edit #{@application.name} - Admin",
      heading: "Edit application",
      subheading: "Update the settings for #{@application.name}.",
      admin_mode: true,
      form_mode: "edit",
      form_method: "patch",
      labels: { submit: "Save changes", cancel: "Cancel" },
      help_text: %i[redirect_uri blank_redirect_uri confidential]
                   .index_with { |key| I18n.t("doorkeeper.applications.help.#{key}") },
      allow_blank_redirect_uri: Doorkeeper.configuration.allow_blank_redirect_uri?(@application),
      application: { id: @application.id, persisted: true, name: @application.name.to_s,
                     redirect_uri: @application.redirect_uri.to_s, confidential: @application.confidential?,
                     redirect_to_hca_login: @application.redirect_to_hca_login?, verified: @application.verified?,
                     selected_scopes: @application.scopes.to_a.map(&:to_s) },
      scope_options: all_scope_options,
      errors: { full_messages: @application.errors.full_messages, name: @application.errors[:name],
                redirect_uri: @application.errors[:redirect_uri], scopes: @application.errors[:scopes],
                confidential: @application.errors[:confidential] } }
  end

  def all_scope_options
    default_scopes = Doorkeeper.configuration.default_scopes.to_a.map(&:to_s)
    optional_scopes = Doorkeeper.configuration.optional_scopes.to_a.map(&:to_s)
    (default_scopes + optional_scopes).uniq.map { |scope|
      { value: scope, description: I18n.t(scope, scope: %i[doorkeeper scopes], default: scope.humanize),
        default: default_scopes.include?(scope) }
    }
  end

  def show_labels
    %i[application_id secret secret_hashed scopes confidential callback_urls actions not_defined]
      .index_with { |key| I18n.t("doorkeeper.applications.show.#{key}") }
  end
end
