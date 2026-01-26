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

      response(200, 'successful') do
        let(:command) { '/timedump' }
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

  path '/timedump/slack/commands' do
    post('Handle Timedump Command') do
      tags 'Slack'
      description 'Handle incoming Slack slash commands for Timedump (/timedump).'
      consumes 'application/x-www-form-urlencoded'
      produces 'application/json'

      parameter name: :command, in: :formData, type: :string
      parameter name: :text, in: :formData, type: :string
      parameter name: :user_id, in: :formData, type: :string
      parameter name: :response_url, in: :formData, type: :string

      response(200, 'successful') do
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
end
