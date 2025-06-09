class CreatePhysicalMails < ActiveRecord::Migration[8.0]
  def change
    create_table :physical_mails do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :mission_type, null: false
      t.integer :status, null: false, default: 0
      t.string :theseus_id

      t.timestamps
    end
  end
end
