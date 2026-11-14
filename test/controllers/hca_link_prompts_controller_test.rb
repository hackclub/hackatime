require "test_helper"
require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

class HCALinkPromptsControllerTest < ActionDispatch::IntegrationTest
  WEEK_ONE = HCATransition::SKIPPABLE_UNTIL - 1.day
  WEEK_TWO = HCATransition::SKIPPABLE_UNTIL
  FINAL_WEEK = HCATransition::REQUIRED_FOR_EVERY_SESSION_FROM

  test "an unlinked account that signed in by email is sent to the link page from other pages" do
    travel_to WEEK_ONE do
      sign_in_as(create(:user, :unlinked))

      get my_settings_path

      assert_redirected_to hca_link_prompt_path(continue: "/my/settings")
      follow_redirect!
      assert_response :success
      assert_inertia_component "Auth/LinkHackClub"
      assert_equal true, inertia.props["skippable"]
      assert_equal "/my/settings", inertia.props["continue_param"]
    end
  end

  test "a linked account is never sent to the link page" do
    travel_to FINAL_WEEK do
      sign_in_as(create(:user))

      get my_settings_path
      assert_response :success

      get hca_link_prompt_path(continue: "/my/settings")
      assert_redirected_to "/my/settings"

      get hca_link_prompt_path(continue: "https://evil.example.com/phish")
      assert_redirected_to root_path
    end
  end

  test "a signed-out visitor to the link page is sent to sign in" do
    get hca_link_prompt_path(continue: "/my/settings")

    assert_redirected_to signin_path(continue: "/my/settings")
  end

  test "Not now lets the session carry on in the first week" do
    travel_to WEEK_ONE do
      sign_in_as(create(:user, :unlinked))

      delete hca_link_prompt_path(continue: "/my/settings")

      assert_redirected_to "/my/settings"
      follow_redirect!
      assert_response :success
    end
  end

  test "Not now does not leave the site for an outside address" do
    travel_to WEEK_ONE do
      sign_in_as(create(:user, :unlinked))

      delete hca_link_prompt_path(continue: "https://evil.example.com/phish")

      assert_redirected_to root_path
    end
  end

  test "Not now is refused once the first week is over" do
    travel_to WEEK_TWO do
      sign_in_as(create(:user, :unlinked))

      delete hca_link_prompt_path(continue: "/my/settings")
      assert_redirected_to hca_link_prompt_path(continue: "/my/settings")

      get my_settings_path
      assert_redirected_to hca_link_prompt_path(continue: "/my/settings")
      follow_redirect!
      assert_equal false, inertia.props["skippable"]
    end
  end

  test "a session that chose Not now is asked again in the final week" do
    user = create(:user, :unlinked)
    travel_to WEEK_ONE do
      sign_in_as(user)
      delete hca_link_prompt_path
    end

    travel_to WEEK_TWO do
      get my_settings_path
      assert_response :success
    end

    travel_to FINAL_WEEK do
      get my_settings_path
      assert_redirected_to hca_link_prompt_path(continue: "/my/settings")
      follow_redirect!
      assert_equal false, inertia.props["skippable"]

      delete hca_link_prompt_path
      get my_settings_path
      assert_redirected_to hca_link_prompt_path(continue: "/my/settings")
    end
  end

  test "a failed link returns to the link page with its reason and the same destination" do
    travel_to WEEK_TWO do
      holder = create(:user, hca_id: "hca-held")
      create(:heartbeat, user: holder)
      sign_in_as(create(:user, :unlinked))
      stub_hca_identity(id: "hca-held")

      get hca_auth_path(continue: "/my/settings")
      get "/auth/hca/callback", params: { error: "access_denied" }
      assert_redirected_to "/my/settings"

      get hca_auth_path(continue: "/my/settings")
      get "/auth/hca/callback", params: { code: "oauth-code", state: session[:hca_oauth_state_nonce] }
      assert_redirected_to "/my/settings"

      follow_redirect!
      assert_redirected_to hca_link_prompt_path(continue: "/my/settings")
      follow_redirect!

      messages = inertia.props.dig("layout", "nav", "flash").pluck("message")
      assert messages.any? { |message| message.include?("already has its own Hackatime account") }, messages.inspect
    end
  end

  test "linking from the page returns to where the account was going" do
    travel_to FINAL_WEEK do
      user = create(:user, :unlinked)
      sign_in_as(user)
      stub_hca_identity(id: "hca-linking")

      get hca_auth_path(continue: "/my/settings")
      get "/auth/hca/callback", params: { code: "oauth-code", state: session[:hca_oauth_state_nonce] }

      assert_equal "hca-linking", user.reload.hca_id
      assert_redirected_to "/my/settings"
      follow_redirect!
      assert_response :success
    end
  end

  test "an unlinked account that is pending deletion reaches its deletion page in the final week" do
    travel_to FINAL_WEEK do
      user = create(:user, :unlinked)
      create(:deletion_request, user: user)
      sign_in_as(user)

      get my_settings_path
      assert_redirected_to deletion_path
      follow_redirect!

      assert_response :success
      assert_inertia_component "DeletionRequests/Show"
    end
  end

  test "an admin impersonating an unlinked account is not sent to the link page" do
    travel_to FINAL_WEEK do
      admin = create(:user, :admin)
      target = create(:user, :unlinked)
      sign_in_as(admin)
      get impersonate_user_path(target.id)

      get my_settings_path

      assert_response :success
      assert_equal target.id, session[:user_id]
    end
  end

  test "an unlinked account's API key keeps working in the final week" do
    travel_to FINAL_WEEK do
      api_key = create(:api_key, user: create(:user, :unlinked))

      get "/api/v1/users/my/heartbeats/spans", headers: { "Authorization" => "Bearer #{api_key.token}" }

      assert_response :success
    end
  end

  private

  def stub_hca_identity(identity)
    stub_request(:post, "#{HCAService.host}/oauth/token")
      .to_return(body: { access_token: "hca-token" }.to_json)
    stub_request(:get, "#{HCAService.host}/api/v1/me")
      .with(headers: { "Authorization" => "Bearer hca-token" })
      .to_return(body: { identity: identity, scopes: %w[email slack_id] }.to_json)
  end
end
