require "test_helper"

class DocumentationFeedbacksControllerTest < ActionDispatch::IntegrationTest
  test "creates and updates anonymous feedback for a visitor and path" do
    payload = feedback_payload(visitor_token: SecureRandom.uuid)

    assert_difference("DocumentationFeedback.count", 1) do
      post "/docs/feedback", params: payload, as: :json
    end
    assert_response :created

    post "/docs/feedback", params: payload.merge(helpful: false), as: :json

    assert_response :no_content
    assert_equal false, DocumentationFeedback.last.helpful
  end

  test "uses the signed-in user and ignores the visitor token" do
    user = User.create!(timezone: "UTC")
    sign_in_as(user)
    visitor_token = SecureRandom.uuid

    assert_difference("DocumentationFeedback.count", 1) do
      post "/docs/feedback", params: feedback_payload(visitor_token: visitor_token), as: :json
    end

    feedback = DocumentationFeedback.last
    assert_response :created
    assert_equal user, feedback.user
    assert_nil feedback.visitor_token

    assert_no_difference("DocumentationFeedback.count") do
      post "/docs/feedback", params: feedback_payload(visitor_token: visitor_token, helpful: false), as: :json
    end

    assert_response :no_content
    assert_equal false, feedback.reload.helpful
  end

  test "rejects invalid feedback" do
    assert_no_difference("DocumentationFeedback.count") do
      post "/docs/feedback", params: feedback_payload(path: "/not-docs"), as: :json
    end

    assert_response :unprocessable_entity
  end

  private

  def feedback_payload(overrides = {})
    {
      helpful: true,
      path: "/docs/editors/android-studio",
      title: "Android Studio - Hackatime Docs",
      visitor_token: SecureRandom.uuid
    }.merge(overrides)
  end
end
