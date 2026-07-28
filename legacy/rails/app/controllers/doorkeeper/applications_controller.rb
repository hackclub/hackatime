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

    FORM_LABELS = {
      new: { component: "OAuthApplications/New", title_key: "doorkeeper.applications.new.title",
             subheading: "Create a new OAuth application to integrate with Hackatime.",
             form_mode: "new", form_method: "post" },
      edit: { component: "OAuthApplications/Edit", title_key: "doorkeeper.applications.edit.title",
              subheading_template: "Update the settings for %{name}.",
              form_mode: "edit", form_method: "patch" }
    }.freeze

    def render_application_form_error(action)
      meta = FORM_LABELS[action]
      respond_to do |format|
        format.html do
          render inertia: meta[:component], props: form_props(action: action), status: :unprocessable_entity
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
        applications: @applications.map { |a|
          { id: a.id, name: a.name, verified: a.verified?, confidential: a.confidential?,
            scopes: a.scopes.to_a.map(&:to_s), redirect_uris: redirect_uris_for(a) }
        } }
    end

    def show_props
      secret = flash[:application_secret].presence
      {
        page_title: "#{@application.name} - OAuth Application",
        heading: I18n.t("doorkeeper.applications.show.title", name: @application.name),
        subheading: "OAuth application credentials and settings.",
        application: {
          id: @application.id,
          name: @application.name,
          uid: @application.uid,
          verified: @application.verified?,
          confidential: @application.confidential?,
          redirect_to_hca_login: @application.redirect_to_hca_login?,
          scopes: @application.scopes.to_a.map(&:to_s),
          redirect_uris: redirect_uris_for(@application),
          can_toggle_verified: current_user&.admin_level_superadmin? || current_user&.admin_level_ultraadmin? || false
        },
        secret: {
          value: secret,
          hashed: secret.blank? && Doorkeeper.config.application_secret_hashed?,
          just_rotated: flash[:application_secret].present?
        },
        labels: %i[application_id secret secret_hashed scopes confidential callback_urls actions not_defined]
                  .index_with { |k| I18n.t("doorkeeper.applications.show.#{k}") },
        confirmations: {
          rotate_secret: "Are you sure? This will invalidate your current secrets and break existing integrations."
        }
      }
    end

    def form_props(action:)
      meta = FORM_LABELS[action]
      heading = I18n.t(meta[:title_key])
      subheading = meta[:subheading] || format(meta[:subheading_template], name: @application.name)
      {
        page_title: heading,
        heading: heading,
        subheading: subheading,
        form_mode: meta[:form_mode],
        form_method: meta[:form_method],
        labels: {
          submit: I18n.t("doorkeeper.applications.buttons.submit"),
          cancel: I18n.t("doorkeeper.applications.buttons.cancel")
        },
        help_text: %i[redirect_uri blank_redirect_uri confidential]
                     .index_with { |k| I18n.t("doorkeeper.applications.help.#{k}") },
        allow_blank_redirect_uri: Doorkeeper.configuration.allow_blank_redirect_uri?(@application),
        application: {
          id: @application.id,
          persisted: @application.persisted?,
          name: @application.name.to_s,
          redirect_uri: @application.redirect_uri.to_s,
          confidential: @application.confidential?,
          redirect_to_hca_login: @application.redirect_to_hca_login?,
          verified: @application.verified?,
          selected_scopes: selected_scopes_for(@application)
        },
        scope_options: all_scope_options,
        errors: {
          full_messages: @application.errors.full_messages,
          name: @application.errors[:name],
          redirect_uri: @application.errors[:redirect_uri],
          scopes: @application.errors[:scopes],
          confidential: @application.errors[:confidential]
        }
      }
    end

    def selected_scopes_for(application)
      scopes = application.scopes.to_a.map(&:to_s)
      return scopes if scopes.any? || application.persisted?
      Doorkeeper.configuration.default_scopes.to_a.map(&:to_s)
    end

    def all_scope_options
      default_scopes = Doorkeeper.configuration.default_scopes.to_a.map(&:to_s)
      optional_scopes = Doorkeeper.configuration.optional_scopes.to_a.map(&:to_s)
      optional_scopes -= [ OauthApplication::ADMIN_SCOPE ] unless can_assign_admin_scope?

      (default_scopes + optional_scopes).uniq.map { |scope|
        { value: scope,
          description: I18n.t(scope, scope: %i[doorkeeper scopes], default: scope.humanize),
          default: default_scopes.include?(scope) }
      }
    end

    def redirect_uris_for(application) = application.redirect_uri.to_s.split
  end
end
