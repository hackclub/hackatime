require "application_system_test_case"

class Admin::AccountMergerTest < ApplicationSystemTestCase
  test "ultraadmin can merge a newer account into an older account" do
    admin = User.create!(timezone: "UTC", admin_level: :ultraadmin, username: "ultraadmin")
    older = User.create!(timezone: "UTC", username: "older_merge_target")
    newer = User.create!(timezone: "UTC", username: "newer_merge_target")

    older.update_column(:created_at, 2.days.ago)
    newer.update_column(:created_at, 1.day.ago)

    heartbeat = Heartbeat.create!(user: newer, time: Time.current.to_i, source_type: :test_entry)
    api_key = ApiKey.create!(user: newer, name: "Merge Test Key")
    newer.email_addresses.create!(email: "newer@example.com", source: :signing_in)
    newer.sign_in_tokens.create!(auth_type: :email)
    oauth_app = newer.oauth_applications.create!(
      name: "Merge Test App",
      redirect_uri: "https://example.com/callback",
      scopes: "profile",
      confidential: true
    )
    Doorkeeper::AccessToken.create!(
      application: oauth_app,
      resource_owner_id: newer.id,
      scopes: "profile",
      expires_in: 1.hour.to_i
    )
    Doorkeeper::AccessGrant.create!(
      application: oauth_app,
      resource_owner_id: newer.id,
      redirect_uri: oauth_app.redirect_uri,
      scopes: "profile",
      expires_in: 10.minutes.to_i
    )

    sign_in_as(admin)

    visit admin_account_merger_path

    find('[data-testid="older-search"]').set(older.username)
    find("[data-testid='older-result-#{older.id}']").click

    find('[data-testid="newer-search"]').set(newer.username)
    find("[data-testid='newer-result-#{newer.id}']").click

    find('[data-testid="open-merge-confirmation"]').click
    find('[data-testid="confirm-merge"]').click

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
