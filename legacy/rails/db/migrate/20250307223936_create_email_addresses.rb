class CreateEmailAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :email_addresses do |t|
      t.string :email
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    add_index :email_addresses, :email, unique: true
  end
end
