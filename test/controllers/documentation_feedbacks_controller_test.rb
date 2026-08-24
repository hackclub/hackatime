require "test_helper"

class DocumentationFeedbacksControllerTest < ActionDispatch::IntegrationTest
  test "creates and updates anonymous feedback for a visitor and path" do
    payload = feedback_payload(visitor_token: SecureRandom.uuid)

    assert_difference("DocumentationFeedback.count", 1) do
      post_feedback payload
    end
    assert_response :created

    post_feedback payload.merge(path: "#{payload[:path]}///", helpful: false)

    assert_response :no_content
    assert_equal false, DocumentationFeedback.last.helpful
  end

  test "uses the signed-in user and ignores the visitor token" do
    user = create(:user)
    sign_in_as(user)
    visitor_token = SecureRandom.uuid

    assert_difference("DocumentationFeedback.count", 1) do
      post_feedback feedback_payload(visitor_token: visitor_token)
    end

    feedback = DocumentationFeedback.last
    assert_response :created
    assert_equal user, feedback.user
    assert_nil feedback.visitor_token

    assert_no_difference("DocumentationFeedback.count") do
      post_feedback feedback_payload(visitor_token: visitor_token, helpful: false)
    end

    assert_response :no_content
    assert_equal false, feedback.reload.helpful
  end

  test "rejects invalid feedback" do
    assert_no_difference("DocumentationFeedback.count") do
      post_feedback feedback_payload(path: "/not-docs")
    end

    assert_response :unprocessable_entity
  end

  test "rejects non-boolean feedback" do
    [ "no", "true", 1, nil ].each do |helpful|
      assert_no_difference("DocumentationFeedback.count") do
        post_feedback feedback_payload(helpful: helpful)
      end
      assert_response :unprocessable_entity
    end
  end

  test "rejects non-string feedback fields" do
    [
      { path: [] },
      { title: 1 },
      { visitor_token: {} }
    ].each do |attributes|
      assert_no_difference("DocumentationFeedback.count") do
        post_feedback feedback_payload(attributes)
      end
      assert_response :unprocessable_entity
    end
  end

  test "rejects requests without same-origin JSON" do
    payload = feedback_payload

    post "/docs/feedback", params: payload, headers: { "Origin" => "https://example.com" }, as: :json
    assert_response :forbidden

    post "/docs/feedback", params: payload, headers: same_origin_headers
    assert_response :forbidden
  end

  private

  def post_feedback(payload)
    post "/docs/feedback", params: payload, headers: same_origin_headers, as: :json
  end

  def same_origin_headers
    { "Origin" => "http://www.example.com" }
  end

  def feedback_payload(overrides = {})
    {
      helpful: true,
      path: "/docs/editors/android-studio",
      title: "Android Studio - Hackatime Docs",
      visitor_token: SecureRandom.uuid
    }.merge(overrides)
  end
end
