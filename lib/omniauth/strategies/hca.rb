# frozen_string_literal: true

module OmniAuth
  module Strategies
    class Hca < OpenIDConnect
      option :name, "hca"

      def credentials = {}

      private

      def access_token
        return @access_token if @access_token

        token_request_params = {
          scope: (options.scope if options.send_scope_to_token_endpoint),
          client_auth_method: options.client_auth_method
        }
        token_request_params[:code_verifier] = session.delete("omniauth.pkce.verifier") if options.pkce

        @access_token = client.access_token!(token_request_params)
        verify_id_token!(@access_token.id_token)
        @access_token
      end

      def verify_id_token!(raw_id_token)
        if raw_id_token.blank?
          raise CallbackError.new(error: :missing_id_token, reason: "HCA did not return an ID token")
        end

        id_token = decode_id_token(raw_id_token)
        id_token.verify!(
          issuer: options.issuer,
          client_id: client_options.identifier,
          nonce: stored_nonce
        )
        validate_authorized_party!(id_token.raw_attributes)
        validate_issued_at!(id_token.raw_attributes)
      end

      def user_info
        return @user_info if @user_info

        id_token_attributes = decode_id_token(access_token.id_token).raw_attributes
        remote_user_info = access_token.userinfo!.raw_attributes
        unless remote_user_info["sub"].present? && remote_user_info["sub"] == id_token_attributes["sub"]
          raise CallbackError.new(error: :subject_mismatch, reason: "HCA UserInfo subject did not match the ID token")
        end

        @user_info = ::OpenIDConnect::ResponseObject::UserInfo.new(remote_user_info.merge(id_token_attributes))
      end

      def decode_id_token(raw_id_token)
        super
      rescue JSON::JWK::Set::KidNotFound
        raise if @refreshed_hca_jwks

        @refreshed_hca_jwks = true
        @config = nil
        @public_key = nil
        retry
      end

      def validate_authorized_party!(attributes)
        audiences = Array(attributes["aud"])
        return if audiences.one?
        return if attributes["azp"] == client_options.identifier

        raise CallbackError.new(error: :invalid_authorized_party, reason: "HCA ID token has an invalid authorized party")
      end

      def validate_issued_at!(attributes)
        issued_at = Time.at(Integer(attributes.fetch("iat")))
        return if issued_at <= 5.minutes.from_now

        raise CallbackError.new(error: :invalid_issued_at, reason: "HCA ID token was issued in the future")
      rescue ArgumentError, KeyError, TypeError
        raise CallbackError.new(error: :invalid_issued_at, reason: "HCA ID token has an invalid issued-at claim")
      end
    end
  end
end
