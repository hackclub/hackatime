require 'swagger_helper'

RSpec.describe 'Slack Webhooks', type: :request do
  path '/sailors_log/slack/commands' do
    post('Handle Sailor\'s Log Command') do
      tags 'Slack'
      description 'Handle incoming Slack slash commands for Sailor\'s Log (/sailorslog).'
      consumes 'application/x-www-form-urlencoded'
      produces 'application/json'

      parameter name: :command, in: :formData, type: :string
      parameter name: :text, in: :formData, type: :string
      parameter name: :user_id, in: :formData, type: :string
      parameter name: :response_url, in: :formData, type: :string

      response(200, 'successful', document: false) do
        let(:command) { '/sailorslog' }
        let(:text) { 'status update' }
        let(:user_id) { 'U123456' }
        let(:response_url) { 'https://hooks.slack.com/commands/1234/5678' }
        before { allow(Rails.env).to receive(:development?).and_return(true) }
        schema type: :object,
          properties: {
            response_type: { type: :string },
            text: { type: :string, nullable: true },
            blocks: {
              type: :array,
              items: { type: :object }
            }
          }
        run_test!
      end
    end
  end

  path '/slack/events' do
    post('Handle Slack Events') do
      tags 'Slack'
      description 'Handle Slack Events API callbacks for the Hackatime Slack app.'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :event_payload, in: :body, schema: {
        type: :object,
        properties: {
          type: { type: :string },
          challenge: { type: :string },
          event: { type: :object }
        }
      }

      response(200, 'successful', document: false) do
        let(:event_payload) { { type: 'url_verification', challenge: 'challenge-token' } }
        before { allow(Rails.env).to receive(:development?).and_return(true) }
        run_test!
      end
    end
  end

  describe 'POST /slack/events' do
    include ActiveJob::TestHelper

    let(:signing_secret) { 'signing-secret' }
    let(:timestamp) { Time.current.to_i.to_s }

    around do |example|
      original_secret = ENV['SLACK_SIGNING_SECRET']
      ENV['SLACK_SIGNING_SECRET'] = signing_secret
      example.run
    ensure
      ENV['SLACK_SIGNING_SECRET'] = original_secret
    end

    before do
      ActiveJob::Base.queue_adapter = :test
      clear_enqueued_jobs
    end

    def post_signed_event(payload)
      body = payload.to_json
      signature = 'v0=' + OpenSSL::HMAC.hexdigest('SHA256', signing_secret, "v0:#{timestamp}:#{body}")
      post '/slack/events', params: body, headers: {
        'CONTENT_TYPE' => 'application/json',
        'X-Slack-Request-Timestamp' => timestamp,
        'X-Slack-Signature' => signature
      }
    end

    it 'responds to Slack URL verification' do
      post_signed_event(type: 'url_verification', challenge: 'challenge-token')

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('challenge' => 'challenge-token')
    end

    it 'enqueues a profile sync when the Slack email changes' do
      user = User.create!(
        timezone: 'UTC',
        slack_uid: 'U_EVENT_USER',
        slack_username: 'old-name',
        slack_avatar_url: 'https://example.com/old.png'
      )
      user.email_addresses.create!(email: 'old@example.com', source: :slack)

      expect {
        post_signed_event(
          type: 'event_callback',
          event_id: 'EvProfileChanged',
          event: {
            type: 'user_change',
            user: {
              id: user.slack_uid,
              name: 'fallback-name',
              profile: {
                display_name_normalized: user.slack_username,
                image_192: user.slack_avatar_url,
                email: 'new@example.com'
              }
            }
          }
        )
      }.to have_enqueued_job(SlackProfileSyncJob).with(user.id)

      expect(response).to have_http_status(:ok)
    end

    it 'ignores a user_change event when only unrelated profile data changed' do
      user = User.create!(
        timezone: 'UTC',
        slack_uid: 'U_STATUS_USER',
        slack_username: 'same-name',
        slack_avatar_url: 'https://example.com/same.png'
      )

      expect {
        post_signed_event(
          type: 'event_callback',
          event_id: 'EvStatusChanged',
          event: {
            type: 'user_change',
            user: {
              id: user.slack_uid,
              name: 'fallback-name',
              profile: {
                display_name_normalized: user.slack_username,
                image_192: user.slack_avatar_url,
                status_text: 'Coding'
              }
            }
          }
        )
      }.not_to have_enqueued_job(SlackProfileSyncJob)

      expect(response).to have_http_status(:ok)
    end

    it 'rejects requests with an invalid Slack signature' do
      post '/slack/events', params: { type: 'event_callback' }.to_json, headers: {
        'CONTENT_TYPE' => 'application/json',
        'X-Slack-Request-Timestamp' => timestamp,
        'X-Slack-Signature' => 'v0=invalid'
      }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
