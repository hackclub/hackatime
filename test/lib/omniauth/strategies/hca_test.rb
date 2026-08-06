require "test_helper"

class HCAStrategyTest < ActiveSupport::TestCase
  setup do
    @strategy = OmniAuth::Strategies::Hca.new(
      ->(_env) { [ 200, {}, [] ] },
      issuer: "https://auth.hackclub.com",
      pkce: true,
      send_state: true,
      send_nonce: true,
      client_options: {
        identifier: "client-id",
        secret: "client-secret",
        redirect_uri: "https://hackatime.example/auth/hca/callback"
      }
    )
  end

  test "does not expose provider tokens through OmniAuth credentials" do
    assert_empty @strategy.credentials
  end

  test "requires an ID token" do
    error = assert_raises(OmniAuth::Strategies::OpenIDConnect::CallbackError) do
      @strategy.send(:verify_id_token!, nil)
    end

    assert_equal :missing_id_token, error.error
  end

  test "requires UserInfo and ID token subjects to match" do
    access_token = fake_access_token(
      id_token: "raw-id-token",
      user_info: { "sub" => "ident!different", "email" => "person@example.com" }
    )
    @strategy.define_singleton_method(:access_token) { access_token }
    @strategy.define_singleton_method(:decode_id_token) do |_raw_token|
      Struct.new(:raw_attributes).new({ "sub" => "ident!expected" })
    end

    error = assert_raises(OmniAuth::Strategies::OpenIDConnect::CallbackError) do
      @strategy.send(:user_info)
    end

    assert_equal :subject_mismatch, error.error
  end

  test "keeps nonce and PKCE verifier in the server session" do
    client = Class.new do
      attr_accessor :redirect_uri
      attr_reader :authorization_options

      def authorization_uri(options)
        @authorization_options = options
        "https://auth.hackclub.com/oauth/authorize"
      end
    end.new
    env = Rack::MockRequest.env_for("/?login_hint=person%40example.com")
    env["rack.session"] = {}
    @strategy.instance_variable_set(:@env, env)
    @strategy.define_singleton_method(:client) { client }

    @strategy.send(:authorize_uri)

    options = client.authorization_options
    assert_equal "person@example.com", options[:login_hint]
    assert_equal "S256", options[:code_challenge_method]
    assert options[:state].present?
    assert options[:nonce].present?
    assert env["rack.session"]["omniauth.pkce.verifier"].present?
    assert_equal options[:state], env["rack.session"]["omniauth.state"]
    assert_equal options[:nonce], env["rack.session"]["omniauth.nonce"]
  end

  private

  def fake_access_token(id_token:, user_info:)
    Class.new do
      attr_reader :id_token

      define_method(:initialize) do |raw_id_token, attributes|
        @id_token = raw_id_token
        @attributes = attributes
      end

      define_method(:userinfo!) do
        Struct.new(:raw_attributes).new(@attributes)
      end
    end.new(id_token, user_info)
  end
end
