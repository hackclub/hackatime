# frozen_string_literal: true

module CustomDoorkeeper
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    layout "inertia"

    before_action :ensure_admin_scope_allowed!, only: %i[new create]

    def new
      if pre_auth.authorizable?
        if skip_authorization? || matching_token?
          redirect_or_render authorize_response
        else
          render inertia: "OAuthAuthorize/New", props: authorize_props
        end
      else
        render_error
      end
    end

    def show
      render inertia: "OAuthAuthorize/Show", props: {
        page_title: I18n.t("doorkeeper.authorizations.show.title"),
        code: params[:code]
      }
    end

    private

    def ensure_admin_scope_allowed!
      return unless pre_auth.authorizable?
      return unless pre_auth.scopes.include?(OauthApplication::ADMIN_SCOPE)

      application = pre_auth.client.application

      unless application.admin_scope?
        render_oauth_error(
          "Only applications configured with the admin scope can request it.",
          status: :forbidden
        )
        return
      end

      unless application.confidential?
        render_oauth_error(
          "Only confidential applications can request the admin scope.",
          status: :forbidden
        )
        return
      end

      unless application.verified?
        render_oauth_error(
          "Only verified applications can request the admin scope.",
          status: :forbidden
        )
        return
      end

      return if current_resource_owner&.admin_level.in?(Api::Admin::ApplicationController::ADMIN_API_LEVELS)

      render_oauth_error(
        "Only admins can authorize applications that request the admin scope.",
        status: :forbidden
      )
    end

    def render_error
      pre_auth.error_response.raise_exception! if Doorkeeper.config.raise_on_errors?

      if Doorkeeper.configuration.redirect_on_errors? && pre_auth.error_response.redirectable?
        redirect_or_render(pre_auth.error_response)
      else
        render_oauth_error(pre_auth.error_response.body[:error_description])
      end
    end

    def render_oauth_error(desc, status: :ok)
      render inertia: "OAuthAuthorize/Error", props: {
        page_title: I18n.t("doorkeeper.authorizations.error.title"),
        error_description: desc
      }, status: status
    end

    def authorize_props
      a = pre_auth.client.application
      {
        page_title: I18n.t("doorkeeper.authorizations.new.title"),
        client_name: pre_auth.client.name,
        verified: a.verified?,
        has_admin_scope: pre_auth.scopes.include?(OauthApplication::ADMIN_SCOPE),
        scopes: pre_auth.scopes.map { |s|
          { name: s.to_s, description: I18n.t(s, scope: %i[doorkeeper scopes], default: s.to_s.humanize) }
        },
        form_data: {
          csrf_token: form_authenticity_token,
          client_id: pre_auth.client.uid,
          redirect_uri: pre_auth.redirect_uri,
          state: pre_auth.state,
          response_type: pre_auth.response_type,
          response_mode: pre_auth.response_mode,
          scope: pre_auth.scope,
          code_challenge: pre_auth.code_challenge,
          code_challenge_method: pre_auth.code_challenge_method
        }
      }
    end

    def matching_token?
      Doorkeeper.config.reuse_access_token &&
        Doorkeeper::AccessToken.matching_token_for(pre_auth.client, current_resource_owner, pre_auth.scopes).present?
    end
  end
end
