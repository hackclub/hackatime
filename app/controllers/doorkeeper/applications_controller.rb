# frozen_string_literal: true

module Doorkeeper
  class ApplicationsController < InertiaController
    layout "inertia"

    before_action :authenticate_oauth_owner!
    before_action :set_application, only: %i[show edit update destroy rotate_secret]

    def index
      @applications = current_resource_owner.oauth_applications.ordered_by(:created_at)

      respond_to do |format|
        format.html do
          render inertia: "OAuthApplications/Index", props: index_props
        end
        format.json { head :no_content }
      end
    end

    def show
      respond_to do |format|
        format.html do
          render inertia: "OAuthApplications/Show", props: show_props
        end
        format.json { render json: @application, as_owner: true }
      end
    end

    def new
      @application = Doorkeeper.config.application_model.new

      render inertia: "OAuthApplications/New", props: form_props(
        heading: I18n.t("doorkeeper.applications.new.title"),
        subheading: "Create a new OAuth application to integrate with Hackatime.",
        submit_path: oauth_applications_path,
        form_method: "post"
      )
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
        respond_to do |format|
          format.html do
            render inertia: "OAuthApplications/New", props: form_props(
              heading: I18n.t("doorkeeper.applications.new.title"),
              subheading: "Create a new OAuth application to integrate with Hackatime.",
              submit_path: oauth_applications_path,
              form_method: "post"
            ), status: :unprocessable_entity
          end
          format.json do
            errors = @application.errors.full_messages
            render json: { errors: errors }, status: :unprocessable_entity
          end
        end
      end
    end

    def edit
      render inertia: "OAuthApplications/Edit", props: form_props(
        heading: I18n.t("doorkeeper.applications.edit.title"),
        subheading: "Update the settings for #{@application.name}.",
        submit_path: oauth_application_path(@application),
        form_method: "patch"
      )
    end

    def update
      if @application.update(application_params)
        flash[:notice] = I18n.t(:notice, scope: i18n_scope(:update))

        respond_to do |format|
          format.html { redirect_to oauth_application_url(@application) }
          format.json { render json: @application, as_owner: true }
        end
      else
        respond_to do |format|
          format.html do
            render inertia: "OAuthApplications/Edit", props: form_props(
              heading: I18n.t("doorkeeper.applications.edit.title"),
              subheading: "Update the settings for #{@application.name}.",
              submit_path: oauth_application_path(@application),
              form_method: "patch"
            ), status: :unprocessable_entity
          end
          format.json do
            errors = @application.errors.full_messages
            render json: { errors: errors }, status: :unprocessable_entity
          end
        end
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
          format.json do
            errors = @application.errors.full_messages
            render json: { errors: errors }, status: :unprocessable_entity
          end
        end
      end
    end

    private

    def set_application
      @application = current_resource_owner.oauth_applications.find(params[:id])
    end

    def application_params
      params.require(:doorkeeper_application)
            .permit(:name, :redirect_uri, :scopes, :confidential)
    end

    def i18n_scope(action)
      %i[doorkeeper flash applications] << action
    end

    def current_resource_owner
      current_user
    end

    def authenticate_oauth_owner!
      return if current_resource_owner

      redirect_to minimal_login_path(continue: request.fullpath)
    end

    def index_props
      {
        page_title: "OAuth Applications",
        heading: I18n.t("doorkeeper.applications.index.title"),
        subheading: "Manage your OAuth applications that integrate with Hackatime.",
        new_application_path: new_oauth_application_path,
        applications: @applications.map { |application|
          {
            id: application.id,
            name: application.name,
            verified: application.verified?,
            confidential: application.confidential?,
            scopes: application.scopes.to_a.map(&:to_s),
            redirect_uris: redirect_uris_for(application),
            show_path: oauth_application_path(application),
            edit_path: edit_oauth_application_path(application),
            destroy_path: oauth_application_path(application)
          }
        }
      }
    end

    def show_props
      secret = flash[:application_secret].presence || @application.plaintext_secret

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
          scopes: @application.scopes.to_a.map(&:to_s),
          redirect_uris: redirect_uris_for(@application).map { |uri|
            {
              value: uri,
              authorize_path: oauth_authorization_path(
                client_id: @application.uid,
                redirect_uri: uri,
                response_type: "code",
                scope: @application.scopes.to_s
              )
            }
          },
          edit_path: edit_oauth_application_path(@application),
          destroy_path: oauth_application_path(@application),
          rotate_secret_path: rotate_secret_oauth_application_path(@application),
          index_path: oauth_applications_path,
          toggle_verified_path: (
            current_user&.admin_level_superadmin? ?
              toggle_verified_admin_oauth_application_path(@application) :
              nil
          )
        },
        secret: {
          value: secret,
          hashed: secret.blank? && Doorkeeper.config.application_secret_hashed?,
          just_rotated: flash[:application_secret].present?
        },
        labels: {
          application_id: I18n.t("doorkeeper.applications.show.application_id"),
          secret: I18n.t("doorkeeper.applications.show.secret"),
          secret_hashed: I18n.t("doorkeeper.applications.show.secret_hashed"),
          scopes: I18n.t("doorkeeper.applications.show.scopes"),
          confidential: I18n.t("doorkeeper.applications.show.confidential"),
          callback_urls: I18n.t("doorkeeper.applications.show.callback_urls"),
          actions: I18n.t("doorkeeper.applications.show.actions"),
          not_defined: I18n.t("doorkeeper.applications.show.not_defined")
        },
        confirmations: {
          rotate_secret: "Are you sure? This will invalidate your current secrets and break existing integrations."
        }
      }
    end

    def form_props(heading:, subheading:, submit_path:, form_method:)
      {
        page_title: heading,
        heading: heading,
        subheading: subheading,
        submit_path: submit_path,
        form_method: form_method,
        cancel_path: oauth_applications_path,
        labels: {
          submit: I18n.t("doorkeeper.applications.buttons.submit"),
          cancel: I18n.t("doorkeeper.applications.buttons.cancel")
        },
        help_text: {
          redirect_uri: I18n.t("doorkeeper.applications.help.redirect_uri"),
          blank_redirect_uri: I18n.t("doorkeeper.applications.help.blank_redirect_uri"),
          confidential: I18n.t("doorkeeper.applications.help.confidential")
        },
        allow_blank_redirect_uri: Doorkeeper.configuration.allow_blank_redirect_uri?(@application),
        application: {
          id: @application.id,
          persisted: @application.persisted?,
          name: @application.name.to_s,
          redirect_uri: @application.redirect_uri.to_s,
          confidential: @application.confidential?,
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

      (default_scopes + optional_scopes).uniq.map { |scope|
        {
          value: scope,
          description: I18n.t(scope, scope: %i[doorkeeper scopes], default: scope.humanize),
          default: default_scopes.include?(scope)
        }
      }
    end

    def redirect_uris_for(application)
      application.redirect_uri.to_s.split
    end
  end
end
