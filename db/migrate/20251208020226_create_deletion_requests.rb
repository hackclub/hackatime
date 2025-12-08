class CreateDeletionRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :deletion_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.datetime :requested_at, null: false
      t.datetime :admin_approved_at
      t.bigint :admin_approved_by_id
      t.datetime :cancelled_at
      t.datetime :scheduled_deletion_at
      t.datetime :completed_at
      t.integer :status, null: false, default: 0

      t.timestamps
    end

    add_foreign_key :deletion_requests, :users, column: :admin_approved_by_id
    add_index :deletion_requests, :status
    add_index :deletion_requests, [ :user_id, :status ]
  end
end
