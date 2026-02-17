# frozen_string_literal: true

module CustomDoorkeeper
  class AuthorizationsController < Doorkeeper::AuthorizationsController
    layout "inertia"

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

    def render_error
      pre_auth.error_response.raise_exception! if Doorkeeper.config.raise_on_errors?

      if Doorkeeper.configuration.redirect_on_errors? && pre_auth.error_response.redirectable?
        redirect_or_render(pre_auth.error_response)
      else
        render inertia: "OAuthAuthorize/Error", props: {
          page_title: I18n.t("doorkeeper.authorizations.error.title"),
          error_description: pre_auth.error_response.body[:error_description]
        }
      end
    end

    def authorize_props
      app = pre_auth.client.application

      {
        page_title: I18n.t("doorkeeper.authorizations.new.title"),
        client_name: pre_auth.client.name,
        verified: app.verified?,
        scopes: pre_auth.scopes.map { |scope|
          {
            name: scope.to_s,
            description: I18n.t(scope, scope: %i[doorkeeper scopes], default: scope.to_s.humanize)
          }
        },
        form_data: {
          authorize_path: oauth_authorization_path,
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
        Doorkeeper::AccessToken.matching_token_for(
          pre_auth.client,
          current_resource_owner,
          pre_auth.scopes
        ).present?
    end
  end
end
