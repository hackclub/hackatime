require "test_helper"

class SlackActivityDigestJobTest < ActiveJob::TestCase
  def setup
    @original_timeout = Heartbeat.heartbeat_timeout_duration
    Heartbeat.heartbeat_timeout_duration(1.hour)

    @user = User.create!(
      slack_uid: "U999",
      username: "digest-user",
      timezone: "UTC",
      slack_neighborhood_channel: "C999"
    )

    @subscription = SlackActivityDigestSubscription.create!(
      slack_channel_id: "C999",
      timezone: "UTC",
      delivery_hour: 10,
      enabled: true
    )

    create_heartbeat(@user, seconds: 600, occurred_at: Time.utc(2024, 5, 1, 16, 0, 0))
  end

  def teardown
    Heartbeat.heartbeat_timeout_duration(@original_timeout)
    Heartbeat.delete_all
    SlackActivityDigestSubscription.delete_all
    User.delete_all
  end

  def test_job_posts_to_slack
    Time.use_zone("UTC") do
      travel_to Time.utc(2024, 5, 2, 11, 0, 0) do
        captured = {}
        fake_response = Struct.new(:body).new({ ok: true }.to_json)

        client = Class.new do
          def initialize(captured, response)
            @captured = captured
            @response = response
          end

          def post(url, json:)
            @captured[:url] = url
            @captured[:json] = json
            @response
          end
        end.new(captured, fake_response)

        ENV["SLACK_ACTIVITY_DIGEST_BOT_TOKEN"] = "xoxb-test"

        HTTP.stub :auth, ->(*) { client } do
          SlackActivityDigestJob.perform_now(@subscription.id, Time.current.to_i)
        end

        assert_equal "https://slack.com/api/chat.postMessage", captured[:url]
        assert_kind_of Array, captured[:json][:blocks]
        assert captured[:json][:blocks].any?
        assert_not_nil @subscription.reload.last_delivered_at
      ensure
        ENV.delete("SLACK_ACTIVITY_DIGEST_BOT_TOKEN")
      end
    end
  end

  private

  def create_heartbeat(user, seconds:, occurred_at:)
    steps = [ (seconds / 60).to_i, 1 ].max
    step_seconds = seconds / steps.to_f

    (steps + 1).times do |index|
      ts = occurred_at.to_i + (index * step_seconds).round
      Heartbeat.create!(
        user: user,
        time: ts,
        project: "DigestProject",
        source_type: :direct_entry
      )
    end
  end
end
