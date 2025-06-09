class AddSourceToEmailAddresses < ActiveRecord::Migration[8.0]
  def change
    add_column :email_addresses, :source, :integer, null: true
  end
end
