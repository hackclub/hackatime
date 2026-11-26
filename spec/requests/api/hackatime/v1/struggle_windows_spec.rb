require "swagger_helper"
require "openssl"

RSpec.describe "Api::Hackatime::V1::StruggleWindows", type: :request do
  let(:user) { create(:user) }
  let(:user_api_key) { create(:api_key, user: user, name: "hackatime-ai-rswag") }
  let(:keypair) { OpenSSL::PKey.generate_key("ED25519") }
  let(:pub_hex) { keypair.raw_public_key.unpack1("H*") }

  before { StruggleNonceStore.clear! }
  after { StruggleNonceStore.clear! }

  def build_signed_window(user:, keypair:, project_hash:, window_start_unix:, prev_chain_hash:, server_nonce:)
    digest = StruggleChainVerifier.compute_digest(
      prev_chain_hash: prev_chain_hash,
      server_nonce: server_nonce,
      user_id: user.id.to_s,
      project_hash: project_hash,
      window_start_unix: window_start_unix,
      raw_seconds: 300,
      credited_seconds: 300,
      effective_multiplier_milli: 1000,
      provenance_mask: 3,
      git_head_sha: "1111111111111111111111111111111111111111"
    )
    sig = keypair.sign(nil, digest)
    {
      user_id: user.id.to_s,
      project_hash: project_hash,
      project_name: "raytracer",
      window_start_unix: window_start_unix,
      raw_seconds: 300,
      credited_seconds: 300,
      struggle_points: 12.5,
      diversity_multiplier: 1.15,
      verify_multiplier: 1.0,
      effective_multiplier: 1.0,
      effective_multiplier_milli: 1000,
      provenance_mask: 3,
      primary_language: "C++",
      ai_harness: "antigravity",
      persisted_diff_lines: 18,
      signal_counts: { "SIG_ARCH_STEER" => 1, "SIG_VERIFY_EXEC" => 1 },
      signal_breakdown: [
        { signal_code: "SIG_ARCH_STEER", trigger_count: 1, raw_points: 4.0, awarded_points: 4.0, provenance_mask: 2, gate_status: "awarded" },
        { signal_code: "SIG_VERIFY_EXEC", trigger_count: 1, raw_points: 3.0, awarded_points: 3.0, provenance_mask: 1, gate_status: "awarded" }
      ],
      git_head_sha: "1111111111111111111111111111111111111111",
      prev_chain_hash: prev_chain_hash,
      server_nonce: server_nonce,
      chain_hash_hex: digest.unpack1("H*"),
      ed25519_sig_hex: sig.unpack1("H*")
    }
  end

  path "/api/hackatime/v1/users/{id}/ed25519_key" do
    put("Register or rotate Ed25519 public key for StruggleTrack") do
      tags "StruggleTrack"
      description "Registers the user's 32-byte Ed25519 public key (hex-encoded) used to verify signed Struggle Telemetry Protocol (STP v1) window chains."
      consumes "application/json"
      produces "application/json"
      security [ Bearer: [], ApiKeyAuth: [] ]

      parameter name: :id, in: :path, type: :string,
                description: 'User ID or "current" (recommended). The authenticated user is resolved from the API token.'
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          ed25519_public_key_hex: {
            type: :string,
            description: "64-character hex-encoded Ed25519 public key (32 raw bytes).",
            example: "d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"
          }
        },
        required: [ "ed25519_public_key_hex" ]
      }

      response(200, "public key registered") do
        let(:Authorization) { "Bearer #{user_api_key.token}" }
        let(:api_key) { user_api_key.token }
        let(:id) { "current" }
        let(:body) { { ed25519_public_key_hex: pub_hex } }

        schema type: :object,
          properties: {
            updated: { type: :boolean, example: true }
          },
          required: [ "updated" ]

        run_test!
      end

      response(400, "invalid public key") do
        let(:Authorization) { "Bearer #{user_api_key.token}" }
        let(:api_key) { user_api_key.token }
        let(:id) { "current" }
        let(:body) { { ed25519_public_key_hex: "not-hex" } }

        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end

      response(401, "unauthorized") do
        let(:Authorization) { "Bearer invalid" }
        let(:api_key) { "invalid" }
        let(:id) { "current" }
        let(:body) { { ed25519_public_key_hex: pub_hex } }

        run_test!
      end
    end
  end

  path "/api/hackatime/v1/users/{id}/struggle_nonce" do
    get("Issue ephemeral StruggleTrack server nonce") do
      tags "StruggleTrack"
      description "Issues a short-lived cryptographic server nonce bound to the authenticated user for signing StruggleTrack (STP v1) windows."
      produces "application/json"
      security [ Bearer: [], ApiKeyAuth: [] ]

      parameter name: :id, in: :path, type: :string,
                description: 'User ID or "current" (recommended). The authenticated user is resolved from the API token.'

      response(200, "nonce issued") do
        let(:Authorization) { "Bearer #{user_api_key.token}" }
        let(:api_key) { user_api_key.token }
        let(:id) { "current" }

        schema type: :object,
          properties: {
            server_nonce: { type: :string, example: "0123456789abcdef0123456789abcdef" },
            user_id: { type: :string, example: "42" },
            expires_in_seconds: { type: :integer, example: 86400 }
          },
          required: %w[server_nonce user_id expires_in_seconds]

        run_test!
      end

      response(401, "unauthorized") do
        let(:Authorization) { "Bearer invalid" }
        let(:api_key) { "invalid" }
        let(:id) { "current" }

        run_test!
      end
    end
  end

  path "/api/hackatime/v1/users/{id}/struggle_windows" do
    post("Ingest signed StruggleTrack (STP v1) windows") do
      tags "StruggleTrack"
      description "Verifies and ingests a batch of up to 100 Ed25519-signed, hash-chained 5-minute Struggle Windows as unconverted Struggle Points."
      consumes "application/json"
      produces "application/json"
      security [ Bearer: [], ApiKeyAuth: [] ]

      parameter name: :id, in: :path, type: :string,
                description: 'User ID or "current" (recommended). The authenticated user is resolved from the API token.'
      parameter name: :struggle_windows, in: :body, schema: {
        type: :array,
        description: "Ordered array of signed Struggle Windows (max 100 per request).",
        items: {
          type: :object,
          properties: {
            user_id: { type: :string, example: "42" },
            project_hash: { type: :string, example: "b" * 64 },
            project_name: { type: :string, nullable: true, example: "raytracer" },
            window_start_unix: { type: :integer, format: :int64, example: 1763900400 },
            raw_seconds: { type: :integer, example: 300 },
            credited_seconds: { type: :integer, example: 300 },
            struggle_points: { type: :number, example: 12.5 },
            diversity_multiplier: { type: :number, example: 1.15 },
            verify_multiplier: { type: :number, example: 1.0 },
            effective_multiplier: { type: :number, example: 1.0 },
            effective_multiplier_milli: { type: :integer, example: 1000 },
            provenance_mask: { type: :integer, example: 3 },
            persisted_diff_lines: { type: :integer, example: 18 },
            primary_language: { type: :string, nullable: true, example: "C++" },
            ai_harness: { type: :string, example: "antigravity" },
            git_head_sha: { type: :string, nullable: true, example: "1111111111111111111111111111111111111111" },
            signal_counts: { type: :object, additionalProperties: { type: :integer } },
            anomaly_flags: { type: :array, items: { type: :string } },
            signal_breakdown: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  signal_code: { type: :string, example: "SIG_ARCH_STEER" },
                  trigger_count: { type: :integer, example: 1 },
                  raw_points: { type: :number, example: 4.0 },
                  awarded_points: { type: :number, example: 4.0 },
                  provenance_mask: { type: :integer, example: 2 },
                  gate_status: { type: :string, example: "awarded" }
                }
              }
            },
            prev_chain_hash: { type: :string, example: "0" * 64 },
            server_nonce: { type: :string, example: "0123456789abcdef0123456789abcdef" },
            chain_hash_hex: { type: :string, example: "a" * 64 },
            ed25519_sig_hex: { type: :string, example: "f" * 128 }
          },
          required: %w[
            project_hash window_start_unix raw_seconds credited_seconds struggle_points
            diversity_multiplier effective_multiplier effective_multiplier_milli
            prev_chain_hash server_nonce chain_hash_hex ed25519_sig_hex
          ]
        }
      }

      response(200, "windows accepted") do
        let(:Authorization) { "Bearer #{user_api_key.token}" }
        let(:api_key) { user_api_key.token }
        let(:id) { "current" }
        let(:issued_nonce) { StruggleNonceStore.issue(user_id: user.id) }
        let(:struggle_windows) do
          [
            build_signed_window(
              user: user,
              keypair: keypair,
              project_hash: "b" * 64,
              window_start_unix: ((Time.current.to_i / 300) * 300) - 900,
              prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
              server_nonce: issued_nonce
            )
          ]
        end

        before { user.update!(ed25519_public_key: keypair.raw_public_key) }

        schema type: :object,
          properties: {
            accepted: { type: :integer, example: 1 },
            next_server_nonce: { type: :string, example: "fedcba9876543210fedcba9876543210" }
          },
          required: %w[accepted next_server_nonce]

        run_test!
      end

      response(400, "missing Ed25519 public key or invalid payload") do
        let(:Authorization) { "Bearer #{user_api_key.token}" }
        let(:api_key) { user_api_key.token }
        let(:id) { "current" }
        let(:struggle_windows) { [] }

        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end

      response(401, "unauthorized") do
        let(:Authorization) { "Bearer invalid" }
        let(:api_key) { "invalid" }
        let(:id) { "current" }
        let(:struggle_windows) { [] }

        run_test!
      end

      response(403, "invalid nonce, chain linkage or signature") do
        let(:Authorization) { "Bearer #{user_api_key.token}" }
        let(:api_key) { user_api_key.token }
        let(:id) { "current" }
        let(:struggle_windows) do
          [
            build_signed_window(
              user: user,
              keypair: keypair,
              project_hash: "c" * 64,
              window_start_unix: ((Time.current.to_i / 300) * 300) - 900,
              prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
              server_nonce: "deadbeefdeadbeefdeadbeefdeadbeef"
            )
          ]
        end

        before { user.update!(ed25519_public_key: keypair.raw_public_key) }

        schema "$ref" => "#/components/schemas/Error"
        run_test!
      end
    end
  end
end
