require "application_system_test_case"

class Admin::AccountMergerTest < ApplicationSystemTestCase
  test "ultraadmin can merge a newer account into an older account" do
    admin = create(:user, :with_email, :ultraadmin, username: "ultraadmin")
    older = create(:user, username: "older_merge_target")
    newer = create(:user, username: "newer_merge_target")

    older.update_column(:created_at, 2.days.ago)
    newer.update_column(:created_at, 1.day.ago)

    heartbeat = create(:heartbeat, user: newer, time: Time.current.to_i, source_type: :test_entry)
    api_key = create(:api_key, user: newer, name: "Merge Test Key")
    create(:email_address, user: newer, email: "newer@example.com", source: :signing_in)
    create(:sign_in_token, user: newer, auth_type: :email)
    oauth_app = create(
      :oauth_application,
      owner: newer,
      name: "Merge Test App",
      redirect_uri: "https://example.com/callback",
      scopes: "profile",
      confidential: true
    )
    create(:oauth_access_token,
      application: oauth_app,
      resource_owner_id: newer.id,
      scopes: "profile",
      expires_in: 1.hour.to_i
    )
    create(:oauth_access_grant,
      application: oauth_app,
      resource_owner_id: newer.id,
      redirect_uri: oauth_app.redirect_uri,
      scopes: "profile",
      expires_in: 10.minutes.to_i
    )

    sign_in_as(admin)

    visit admin_account_merger_path

    fill_in "Older user", with: older.username
    find("[role='option']", text: "ID: #{older.id}").click

    fill_in "Newer user", with: newer.username
    find("[role='option']", text: "ID: #{newer.id}").click

    click_on "Merge & Delete"
    within("[role='dialog']", text: "Confirm Account Merge") do
      click_on "Merge & Delete"
    end

    assert_text "Merge complete!"
    assert_text "3 sessions/tokens revoked"
    assert_text "3 related records cleaned up"

    assert_equal older.id, Heartbeat.find(heartbeat.id).user_id
    assert_equal older.id, ApiKey.find(api_key.id).user_id
    assert_nil User.find_by(id: newer.id)
    assert_equal 0, Doorkeeper::AccessToken.where(resource_owner_id: newer.id).count
    assert_equal 0, Doorkeeper::AccessGrant.where(resource_owner_id: newer.id).count
  end
end
