class CreateHCAIdentityConflicts < ActiveRecord::Migration[8.1]
  def change
    create_table :hca_identity_conflicts do |t|
      t.string :hca_id, null: false
      t.string :reason, null: false
      t.references :email_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :slack_user, foreign_key: { to_table: :users, on_delete: :nullify }
      t.datetime :last_seen_at, null: false
      t.integer :occurrences, default: 1, null: false
      t.datetime :resolved_at
      t.timestamps
    end

    add_index :hca_identity_conflicts,
      :hca_id,
      unique: true,
      where: "resolved_at IS NULL",
      name: :index_active_hca_identity_conflicts_on_hca_id
  end
end
