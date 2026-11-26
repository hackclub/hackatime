require "swagger_helper"

RSpec.describe "Api::V1::StruggleBadges", type: :request do
  path "/api/v1/struggle_badge/{username}.svg" do
    get("Render a public SVG StruggleTrack builder card") do
      tags "Badges"
      description <<~DESC
        Returns an embeddable SVG card summarizing a user's converted StruggleTrack
        verified hours, average multiplier, architect score and top stack.
        Requires the user to have public stats lookup enabled.
      DESC
      security []
      produces "image/svg+xml"

      parameter name: :username, in: :path, type: :string, required: true,
                description: "User identifier: Slack UID, username or numeric internal ID."

      response(200, "SVG struggle card badge") do
        let(:badge_user) do
          create(
            :user,
            username: "sp_badge_#{SecureRandom.hex(4)}",
            allow_public_stats_lookup: true
          )
        end
        let(:username) { badge_user.username }

        before do
          badge_user.struggle_windows.create!(
            project_hash: "a" * 64,
            project_name: "hackatime-ai",
            window_start: 1.hour.ago.utc,
            raw_seconds: 300,
            convertible_seconds: 300,
            credited_seconds: 300,
            converted_at: Time.current,
            struggle_points: 12.0,
            diversity_multiplier: 1.15,
            verify_multiplier: 1.0,
            effective_multiplier: 1.0,
            effective_multiplier_milli: 1000,
            provenance_mask: 3,
            primary_language: "Ruby",
            ai_harness: "antigravity",
            signal_counts: { "SIG_ARCH_STEER" => 2 },
            prev_chain_hash: StruggleWindow::GENESIS_CHAIN_HASH,
            server_nonce: "0" * 32,
            chain_hash: "1" * 64,
            signature: "x" * 64
          )
        end

        schema type: :string, description: "SVG markup representing the user's StruggleTrack card."

        run_test! do |response|
          expect(response.content_type).to include("image/svg+xml")
          expect(response.body).to include("HACKATIME AI // @#{badge_user.username}")
        end
      end

      response(404, "user not found or public stats disabled") do
        let(:username) { "definitely-no-such-struggle-user" }

        run_test! do |response|
          expect(response.status).to eq(404)
        end
      end
    end
  end
end
