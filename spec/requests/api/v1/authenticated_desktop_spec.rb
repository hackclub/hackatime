require 'swagger_helper'

RSpec.describe 'Api::V1::Authenticated::Desktop', type: :request do
  let(:user) { create(:user) }
  let(:Authorization) { "Bearer #{create(:oauth_access_token, resource_owner_id: user.id, scopes: 'profile desktop').token}" }
  let(:device) do
    DesktopDevice.build_with_token(user:, name: 'Mac', platform: 'macos', capture_consented_at: Time.current).first.tap(&:save!)
  end
  let(:ship) do
    beacon = EvidenceBeacon.current!
    payload = { focus: 'project', project: 'demo', active_s: 40 }.to_json
    hash = Evidence::Crypto.chain_hash(device.head_hash, beacon.value, payload)
    device.evidence_blocks.create!(user:, evidence_beacon: beacon, seq: 1, minute: beacon.minute, prev_hash: device.head_hash,
      block_hash: hash, payload: JSON.parse(payload), captured_at_ms: beacon.minute * 60_000, received_at: Time.current)
    device.update!(last_seq: 1, head_hash: hash)
    EvidenceShip.create!(user:, desktop_device: device, project: 'demo', from_seq: 1, to_seq: 1, status: :needs_info,
      submitted_at: Time.current, reviewer_question: 'How does the sync work?', flags: [ 'jiggler' ])
  end

  ship_row = {
    type: :object, required: %w[id project status],
    properties: {
      id: { type: :integer }, project: { type: :string },
      status: { type: :string, enum: %w[in_review appeal_in_review question approved approved_in_part rejected] },
      submitted_at: { type: :string, format: 'date-time', nullable: true }, decided_at: { type: :string, format: 'date-time', nullable: true },
      claimed_seconds: { type: :integer }, approved_seconds: { type: :integer, nullable: true }
    }
  }

  path '/api/v1/authenticated/desktop' do
    get('Hackatime Desktop overview') do
      tags 'OAuth2-specific'
      description "The signed-in student's Hackatime theme, paired devices, time tracked today and shipped work. Requires the `desktop` scope. " \
                  'Reviewer flags and scoring details are never included.'
      security [ { OAuth2: [ 'desktop' ] } ]
      produces 'application/json'

      response(200, 'overview') do
        before { ship }
        schema type: :object, required: %w[user today_seconds devices ships], properties: {
          user: { type: :object, properties: {
            name: { type: :string }, username: { type: :string, nullable: true }, avatar_url: { type: :string, nullable: true },
            timezone: { type: :string },
            theme: { type: :object, properties: { value: { type: :string }, label: { type: :string }, color_scheme: { type: :string },
                                                  palette: { type: :object, additionalProperties: { type: :string, nullable: true } } } }
          } },
          today_seconds: { type: :integer },
          devices: { type: :array, items: { type: :object, properties: {
            id: { type: :integer }, name: { type: :string }, platform: { type: :string }, app_version: { type: :string, nullable: true },
            hardware_key: { type: :boolean }, paired_at: { type: :string, format: 'date-time' }, last_seen_at: { type: :string, format: 'date-time', nullable: true }
          } } },
          ships: { type: :array, items: ship_row }
        }
        run_test! { |response| expect(response.body).not_to include('jiggler') }
      end

      response(403, 'token lacks the desktop scope') do
        let(:Authorization) { "Bearer #{create(:oauth_access_token, resource_owner_id: user.id, scopes: 'read').token}" }
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/desktop/ships/{id}' do
    get('One shipped stretch of work') do
      tags 'OAuth2-specific'
      description 'A plain-words reflection on the work, the reviewer conversation, whether it can still be appealed and an access log of every reviewer view.'
      security [ { OAuth2: [ 'desktop' ] } ]
      produces 'application/json'
      parameter name: :id, in: :path, type: :integer

      response(200, 'ship') do
        let(:id) { ship.id }
        schema ship_row.deep_merge(properties: {
          reflection: { type: :string }, started_at: { type: :string, nullable: true }, ended_at: { type: :string, nullable: true },
          frames_shared: { type: :integer }, reviewer_question: { type: :string, nullable: true }, user_answer: { type: :string, nullable: true },
          decision_reason: { type: :string, nullable: true }, appeal: { type: :string, nullable: true }, appealable: { type: :boolean },
          access_log: { type: :array, items: { type: :object, properties: { at: { type: :string }, who: { type: :string }, what: { type: :string } } } }
        })
        run_test! { |response| expect(JSON.parse(response.body)).not_to have_key('flags') }
      end

      response(404, 'not your ship') do
        let(:id) { 0 }
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/desktop/pairings' do
    post('Issue a pairing code for Hackatime Desktop') do
      tags 'OAuth2-specific'
      description 'Called after the student consents to timelapse capture. Returns a one-time code (10 minutes) bound to the app\'s PKCE challenge.'
      security [ { OAuth2: [ 'desktop' ] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[code_challenge consent],
        properties: { code_challenge: { type: :string, description: 'BASE64URL(SHA256(verifier)), 43 characters' }, consent: { type: :boolean } }
      }

      response(201, 'pairing code') do
        let(:body) { { code_challenge: 'A' * 43, consent: true } }
        schema type: :object, required: %w[code deep_link expires_at], properties: {
          code: { type: :string }, deep_link: { type: :string }, expires_at: { type: :string, format: 'date-time' }
        }
        run_test!
      end

      response(422, 'consent missing or challenge invalid') do
        let(:body) { { code_challenge: 'A' * 43, consent: false } }
        run_test!
      end
    end
  end

  path '/api/v1/authenticated/desktop/devices/{id}' do
    delete('Unpair a device') do
      tags 'OAuth2-specific'
      security [ { OAuth2: [ 'desktop' ] } ]
      parameter name: :id, in: :path, type: :integer

      response(204, 'unpaired') do
        let(:id) { device.id }
        run_test! { expect(device.reload.revoked?).to be(true) }
      end
    end
  end

  path '/api/v1/authenticated/desktop/ships/{id}/answer' do
    post("Answer a reviewer's question") do
      tags 'OAuth2-specific'
      security [ { OAuth2: [ 'desktop' ] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :id, in: :path, type: :integer
      parameter name: :body, in: :body, schema: { type: :object, required: [ 'answer' ], properties: { answer: { type: :string, maxLength: 5000 } } }

      response(200, 'answered; back in review') do
        let(:id) { ship.id }
        let(:body) { { answer: 'It diffs local and remote rows by updated_at.' } }
        schema ship_row
        run_test! { |response| expect(JSON.parse(response.body)['status']).to eq('in_review') }
      end
    end
  end

  path '/api/v1/authenticated/desktop/ships/{id}/appeal' do
    post('Appeal a decision') do
      tags 'OAuth2-specific'
      description 'Allowed once, within 90 days of a rejected or partly approved decision. A different reviewer picks it up.'
      security [ { OAuth2: [ 'desktop' ] } ]
      consumes 'application/json'
      produces 'application/json'
      parameter name: :id, in: :path, type: :integer
      parameter name: :body, in: :body, schema: { type: :object, required: [ 'appeal' ], properties: { appeal: { type: :string, maxLength: 5000 } } }

      response(422, 'not appealable') do
        let(:id) { ship.id }
        let(:body) { { appeal: 'Please look again.' } }
        run_test!
      end
    end
  end
end
