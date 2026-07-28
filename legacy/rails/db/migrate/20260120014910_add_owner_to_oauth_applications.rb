class AddOwnerToOauthApplications < ActiveRecord::Migration[8.1]
  def change
    add_reference :oauth_applications, :owner, polymorphic: true, null: true, index: true
  end
end
