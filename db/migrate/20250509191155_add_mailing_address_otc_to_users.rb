class AddMailingAddressOtcToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :mailing_address_otc, :string
  end
end
