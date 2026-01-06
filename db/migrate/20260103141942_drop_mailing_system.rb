class DropMailingSystem < ActiveRecord::Migration[8.1]
  def up
    drop_table :physical_mails, if_exists: true
    drop_table :mailing_addresses, if_exists: true
    remove_column :users, :mailing_address_otc, if_exists: true
  end

  def down
    create_table :mailing_addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :first_name
      t.string :last_name
      t.string :line_1
      t.string :line_2
      t.string :city
      t.string :state
      t.string :zip_code
      t.string :country
      t.timestamps
    end

    create_table :physical_mails do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :status, default: 0
      t.integer :mission_type
      t.string :theseus_id
      t.timestamps
    end

    add_column :users, :mailing_address_otc, :string
  end
end
