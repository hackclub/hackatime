# frozen_string_literal: true

module Doorkeeper
  class ApplicationsController < InertiaController
    layout "inertia"

    before_action :authenticate_oauth_owner!
    before_action :set_application, only: %i[show edit update destroy rotate_secret]

    def index
      @applications = current_resource_owner.oauth_applications.ordered_by(:created_at)

      respond_to do |format|
        format.html { render inertia: "OAuthApplications/Index", props: index_props }
        format.json { head :no_content }
      end
    end

    def show
      respond_to do |format|
        format.html { render inertia: "OAuthApplications/Show", props: show_props }
        format.json { render json: @application, as_owner: true }
      end
    end

    def new
      @application = Doorkeeper.config.application_model.new
      render inertia: "OAuthApplications/New", props: form_props(action: :new)
    end

    def create
      @application = Doorkeeper.config.application_model.new(application_params)
      @application.owner = current_resource_owner

      if @application.save
        flash[:notice] = I18n.t(:notice, scope: %i[doorkeeper flash applications create])
        flash[:application_secret] = @application.plaintext_secret

        respond_to do |format|
          format.html { redirect_to oauth_application_url(@application) }
          format.json { render json: @application, as_owner: true }
        end
      else
        render_application_form_error(:new)
      end
    end

    def edit
      render inertia: "OAuthApplications/Edit", props: form_props(action: :edit)
    end

    def update
      if @application.update(application_params)
        flash[:notice] = I18n.t(:notice, scope: i18n_scope(:update))

        respond_to do |format|
          format.html { redirect_to oauth_application_url(@application) }
          format.json { render json: @application, as_owner: true }
        end
      else
        render_application_form_error(:edit)
      end
    end

    def destroy
      flash[:notice] = I18n.t(:notice, scope: i18n_scope(:destroy)) if @application.destroy

      respond_to do |format|
        format.html { redirect_to oauth_applications_url }
        format.json { head :no_content }
      end
    end

    def rotate_secret
      @application.renew_secret

      respond_to do |format|
        if @application.save
          format.html do
            flash[:notice] = I18n.t(:notice, scope: i18n_scope(:rotate_secret))
            flash[:application_secret] = @application.plaintext_secret
            redirect_to oauth_application_url(@application)
          end
          format.json { render json: @application, as_owner: true }
        else
          format.html do
            flash[:alert] = I18n.t(:alert, scope: i18n_scope(:rotate_secret))
            redirect_to oauth_application_url(@application)
          end
          format.json { render json: { errors: @application.errors.full_messages }, status: :unprocessable_entity }
        end
      end
    end

    private

    def render_application_form_error(action)
      respond_to do |format|
        format.html do
          component = action == :new ? "OAuthApplications/New" : "OAuthApplications/Edit"
          render inertia: component, props: form_props(action: action), status: :unprocessable_entity
        end
        format.json { render json: { errors: @application.errors.full_messages }, status: :unprocessable_entity }
      end
    end

    def set_application
      @application = current_resource_owner.oauth_applications.find(params[:id])
    end

    def application_params
      permitted = params.require(:doorkeeper_application)
        .permit(:name, :redirect_uri, :confidential, :redirect_to_hca_login, scopes: [])
      permitted[:scopes] = normalize_scopes(permitted[:scopes]).join(" ")
      permitted
    end

    def normalize_scopes(raw)
      scopes = Array(raw).compact_blank.map(&:to_s)
      return scopes if can_assign_admin_scope?

      scopes.delete(OauthApplication::ADMIN_SCOPE)
      scopes |= [ OauthApplication::ADMIN_SCOPE ] if action_name == "update" && @application&.admin_scope?
      scopes
    end

    def can_assign_admin_scope? = current_user&.admin_level.in?(AuthHelpers::ADMIN_LEVELS)

    def i18n_scope(action) = %i[doorkeeper flash applications] << action

    def current_resource_owner = current_user

    def authenticate_oauth_owner!
      redirect_to signin_path(continue: request.fullpath) unless current_resource_owner
    end

    def index_props
      { page_title: "OAuth Applications",
        applications: @applications.map { |application| page_props(application).summary } }
    end

    def show_props
      page_props.show(
        secret: flash[:application_secret].presence,
        can_toggle_verified: current_user&.admin_level_superadmin? || current_user&.admin_level_ultraadmin? || false
      )
    end

    def form_props(action:) = page_props.form(action: action)

    def page_props(application = @application)
      OauthApplicationPageProps.new(application, can_assign_admin_scope: can_assign_admin_scope?)
    end
  end
end
