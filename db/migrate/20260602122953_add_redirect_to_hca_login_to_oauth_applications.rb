class AddRedirectToHCALoginToOauthApplications < ActiveRecord::Migration[8.1]
  def change
    add_column :oauth_applications, :redirect_to_hca_login, :boolean, default: false, null: false
  end
end
