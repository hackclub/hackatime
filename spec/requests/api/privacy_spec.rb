require "swagger_helper"

RSpec.describe "Privacy requests", type: :request do
  let(:signing_key) { OpenSSL::PKey::EC.generate("prime256v1") }
  let(:kid) { SecureRandom.uuid }
  let(:jwks_url) { "https://privacy-#{kid}.example.test/jwks" }
  let(:claims) do
    { iss: "hackclub-privacy", aud: "hackatime", iat: Time.now.to_i,
      exp: Time.now.to_i + 300, jti: SecureRandom.uuid, request_id: SecureRandom.uuid,
      action: "delete", dry_run: true, subject: { emails: [], slack_id: nil, identity_id: nil } }
  end

  around do |example|
    old_url = ENV["PRIVACY_JWKS_URL"]
    ENV["PRIVACY_JWKS_URL"] = jwks_url
    example.run
  ensure
    ENV["PRIVACY_JWKS_URL"] = old_url
  end

  before do
    stub_request(:get, jwks_url).to_return(
      body: { keys: [ JWT::JWK.new(signing_key, kid: kid).export ] }.to_json,
      headers: { "Content-Type" => "application/json" })
  end

  def signed_token(payload)
    JWT.encode(payload, signing_key, "ES256", typ: "JWT", kid: kid)
  end

  %w[delete export].each do |action|
    path "/api/privacy/#{action}" do
      post("#{action.capitalize} the subject's Hackatime data") do
        tags "Privacy"
        description "No request body. Requires a short-lived ES256 Yeeter JWT with issuer hackclub-privacy, audience hackatime and the matching action. Exports report counts without modifying subject data."
        security [ Bearer: [] ]
        produces "application/json"

        response(200, "counts only") do
          let(:Authorization) { "Bearer #{signed_token(claims.merge(action: action))}" }
          schema type: :object, additionalProperties: false,
            required: %w[request_id found dry_run deleted retained],
            properties: {
              request_id: { type: :string }, found: { type: :boolean }, dry_run: { type: :boolean },
              deleted: { type: :object, additionalProperties: { type: :integer, minimum: 0 } },
              retained: { type: :array, items: {
                type: :object, required: %w[type count reason], properties: {
                  type: { type: :string, maxLength: 100 }, count: { type: :integer, minimum: 0 }, reason: { type: :string, maxLength: 500 }
                }
              } }
            }
          run_test! do |response|
            expect(JSON.parse(response.body)).to eq(
              "request_id" => claims[:request_id], "found" => false,
              "dry_run" => true, "deleted" => {}, "retained" => [])
          end
        end

        response(401, "invalid token") do
          let(:Authorization) { "Bearer invalid" }
          schema "$ref" => "#/components/schemas/Error"
          run_test!
        end

        response(400, "action mismatch") do
          let(:Authorization) { "Bearer #{signed_token(claims.merge(action: action == "delete" ? "export" : "delete"))}" }
          schema "$ref" => "#/components/schemas/Error"
          run_test!
        end

        response(409, "replayed token or manual review required") do
          let(:Authorization) { "Bearer #{signed_token(claims.merge(action: action))}" }
          before { PrivacyTokenUse.create!(jti: claims[:jti]) }
          schema "$ref" => "#/components/schemas/Error"
          run_test!
        end

        response(503, "dependency unavailable or work in progress") do
          let(:Authorization) { "Bearer #{signed_token(claims.merge(action: action))}" }
          before { stub_request(:get, jwks_url).to_return(status: 503) }
          schema "$ref" => "#/components/schemas/Error"
          run_test!
        end
      end
    end
  end
end
