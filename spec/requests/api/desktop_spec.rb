require 'swagger_helper'

RSpec.describe 'Api::Desktop::V1', type: :request do
  let(:user) { create(:user) }
  let(:verifier) { SecureRandom.urlsafe_base64(48) }
  let(:challenge) { Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false) }
  let(:paired) { DesktopDevice.build_with_token(user:, name: 'Mac', platform: 'macos', capture_consented_at: Time.current).tap { |device, _| device.save! } }
  let(:device) { paired[0] }
  let(:Authorization) { "Bearer #{paired[1]}" }

  path '/api/desktop/v1/pair' do
    post('Pair Hackatime Desktop') do
      tags 'Desktop'
      description 'Exchanges a one-time pairing code, approved by the signed-in user at /desktop/pair/new, for a device token. ' \
                  'The code only works once, for 10 minutes, and only with the PKCE (S256) verifier of the challenge it was issued for.'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[code code_verifier platform],
        properties: {
          code: { type: :string, example: 'K7Q2M9XW4D' }, code_verifier: { type: :string },
          name: { type: :string, example: "Orpheus's MacBook" }, platform: { type: :string, enum: DesktopDevice::PLATFORMS },
          app_version: { type: :string, example: '0.1.0' }
        }
      }

      response(201, 'paired') do
        let(:body) { { code: DesktopPairing.issue!(user:, code_challenge: challenge, consented: true)[1], code_verifier: verifier, platform: 'macos', name: 'Mac' } }
        schema type: :object, required: %w[token device], properties: {
          token: { type: :string, description: 'Device bearer token. Store it in the OS keystore.' },
          device: { type: :object, properties: {
            uid: { type: :string }, key_tier: { type: :string, enum: DesktopDevice.key_tiers.keys },
            last_seq: { type: :integer }
          } }
        }
        run_test!
      end

      response(401, 'invalid, expired or reused code, or wrong verifier') do
        let(:body) { { code: DesktopPairing.issue!(user:, code_challenge: challenge, consented: true)[1], code_verifier: 'wrong', platform: 'macos' } }
        run_test!
      end
    end
  end

  path '/api/desktop/v1/beacon' do
    get('Current server beacon') do
      tags 'Desktop'
      description 'The server beacon for this minute. Every block must mix in the newest beacon value. `commitment` is the hash of a secret ' \
                  'revealed only when the range is shipped; it picks which timelapse frames are required. `next_expected_at` is when ' \
                  'this device should take this minute\'s first timelapse frame, and another is due every `timelapse_interval_seconds` ' \
                  'after it until the minute ends; a frame within `timelapse_window_seconds` of a due time is on time.'
      security [ { Bearer: [] } ]
      produces 'application/json'

      response(200, 'beacon') do
        schema type: :object, required: %w[minute value commitment next_expected_at head_seq head_hash], properties: {
          minute: { type: :integer, description: 'Unix minute (seconds / 60)' },
          value: { type: :string, description: '32 random bytes, hex' }, commitment: { type: :string },
          next_expected_at: { type: :string, format: 'date-time' },
          timelapse_interval_seconds: { type: :integer }, timelapse_window_seconds: { type: :integer }, head_seq: { type: :integer }, head_hash: { type: :string },
          server_time_ms: { type: :integer }, starts_at: { type: :string, format: 'date-time' }
        }
        run_test!
      end

      response(401, 'unknown or revoked device token') do
        let(:Authorization) { 'Bearer nope' }
        run_test!
      end
    end
  end

  path '/api/desktop/v1/blocks' do
    post('Append minute blocks to the device chain') do
      tags 'Desktop'
      description 'Appends blocks in order. Each block links to the previous hash and the beacon of its minute: ' \
                  '`hash = SHA-256("hkt-chain-v1\\n" || prev || beacon_value || SHA-256(payload))`. When the device enrolled a key, ' \
                  '`signature` is an ECDSA P-256 signature over the 32 hash bytes. Payloads carry summary claims only. ' \
                  'Processing stops at the first rejected block; 409 returns the server head so the client can resync.'
      security [ { Bearer: [] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object, required: [ 'blocks' ],
        properties: { blocks: { type: :array, maxItems: 120, items: {
          type: :object, required: %w[seq minute beacon_minute prev_hash captured_at_ms mono_ms payload hash],
          properties: {
            seq: { type: :integer }, minute: { type: :integer }, beacon_minute: { type: :integer }, prev_hash: { type: :string },
            captured_at_ms: { type: :integer }, mono_ms: { type: :integer },
            payload: { type: :string, description: 'Canonical JSON: focus, project, active_s, keys, clicks, moves, injected, rhythm, jiggler, edits, commits, builds, ai, tree.root, frames[].hash' },
            hash: { type: :string }, signature: { type: :string, nullable: true }
          }
        } } }
      }

      response(201, 'accepted') do
        let(:body) do
          beacon = EvidenceBeacon.current!
          payload = { focus: 'project', project: 'demo', active_s: 40, keys: 50, edits: 2 }.to_json
          { blocks: [ { seq: 1, minute: beacon.minute, beacon_minute: beacon.minute, prev_hash: device.head_hash,
                        captured_at_ms: (Time.current.to_f * 1000).to_i, mono_ms: 1000, payload:,
                        hash: Evidence::Crypto.chain_hash(device.head_hash, beacon.value, payload) } ] }
        end
        schema type: :object, required: %w[accepted head_seq head_hash], properties: {
          accepted: { type: :integer }, head_seq: { type: :integer }, head_hash: { type: :string },
          error: { type: :object, nullable: true, properties: { code: { type: :string }, message: { type: :string }, seq: { type: :integer } } }
        }
        run_test!
      end

      response(409, 'a block was rejected (fork, bad hash, stale beacon, bad signature, not monotonic)') do
        let(:body) do
          beacon = EvidenceBeacon.current!
          { blocks: [ { seq: 1, minute: beacon.minute, beacon_minute: beacon.minute, prev_hash: 'f' * 64,
                        captured_at_ms: (Time.current.to_f * 1000).to_i, mono_ms: 1000, payload: '{"focus":"project"}', hash: 'f' * 64 } ] }
        end
        run_test! { |response| expect(JSON.parse(response.body).dig('error', 'code')).to eq('fork') }
      end
    end
  end

  path '/api/desktop/v1/ships' do
    post('Open a ship over a chain range') do
      tags 'Desktop'
      description 'Opens a draft ship over a closed range and reveals the beacon secrets for it, which pick the required timelapse frames ' \
                  'and the code snapshots the server will spot-check. Clients must check each secret against its published commitment. ' \
                  '`excluded` lists minutes inside the range that the user removed before shipping: they earn nothing, their secrets ' \
                  'are not revealed and none of their frames or snapshots is asked for. Opening a range that already has a draft ' \
                  'updates that draft, and deletes frames uploaded for minutes that are now removed.'
      security [ { Bearer: [] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[project from_seq to_seq],
        properties: {
          project: { type: :string }, from_seq: { type: :integer }, to_seq: { type: :integer },
          excluded: {
            type: :array, description: 'Removed seq ranges, both ends inclusive, in any order. Omitted or empty removes nothing. ' \
                                       'Each must lie inside the ship, at most 200 remain after merging and at least one minute must be kept.',
            items: { type: :object, required: %w[from_seq to_seq], properties: { from_seq: { type: :integer, example: 12 }, to_seq: { type: :integer, example: 15 } } }
          }
        }
      }

      response(201, 'draft ship with what must be revealed') do
        let(:body) do
          beacon = EvidenceBeacon.current!
          payload = '{"focus":"project"}'
          hash = Evidence::Crypto.chain_hash(device.head_hash, beacon.value, payload)
          device.evidence_blocks.create!(user:, evidence_beacon: beacon, seq: 1, minute: beacon.minute, prev_hash: device.head_hash,
            block_hash: hash, payload: JSON.parse(payload), captured_at_ms: beacon.minute * 60_000, received_at: Time.current)
          device.evidence_blocks.create!(user:, evidence_beacon: beacon, seq: 2, minute: beacon.minute + 1, prev_hash: hash,
            block_hash: 'a' * 64, payload: JSON.parse(payload), captured_at_ms: (beacon.minute + 1) * 60_000, received_at: Time.current)
          device.update!(last_seq: 2, head_hash: 'a' * 64)
          { project: 'demo', from_seq: 1, to_seq: 2, excluded: [ { from_seq: 2, to_seq: 2 } ] }
        end
        schema type: :object, required: %w[id status excluded_ranges required_frames spot_check_seqs revealed], properties: {
          id: { type: :integer }, status: { type: :string },
          excluded_ranges: { type: :array, description: 'The removed seq ranges as [from, to] pairs, sorted, with overlapping or adjacent ranges merged',
                             items: { type: :array, items: { type: :integer }, minItems: 2, maxItems: 2 } },
          required_frames: { type: :array, items: { type: :string } },
          spot_check_seqs: { type: :array, items: { type: :integer } },
          revealed: { type: :array, description: 'Secrets of the beacons of kept minutes only',
                      items: { type: :object, properties: { minute: { type: :integer }, secret: { type: :string }, commitment: { type: :string } } } }
        }
        run_test! { |response| expect(JSON.parse(response.body)['excluded_ranges']).to eq([ [ 2, 2 ] ]) }
      end

      response(422, 'range is invalid, beyond the chain or overlaps a submitted ship, or an excluded range is malformed, outside the ship or leaves no minute') do
        let(:body) { { project: 'demo', from_seq: 1, to_seq: 5 } }
        run_test!
      end
    end
  end
end
