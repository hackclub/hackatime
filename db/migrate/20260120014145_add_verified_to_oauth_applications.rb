class AddVerifiedToOauthApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :oauth_applications, :verified, :boolean, default: false, null: false
  end
end
