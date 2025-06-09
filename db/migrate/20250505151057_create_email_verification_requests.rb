class CreateEmailVerificationRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :email_verification_requests do |t|
      t.string :email
      t.references :user, null: false, foreign_key: true
      t.string :token
      t.datetime :expires_at

      t.timestamps
    end
    add_index :email_verification_requests, :email, unique: true
  end
end
