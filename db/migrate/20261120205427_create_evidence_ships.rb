class CreateEvidenceShips < ActiveRecord::Migration[8.1]
  def change
    create_table :evidence_ships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :desktop_device, null: false, foreign_key: true
      t.references :reviewer, foreign_key: { to_table: :users }
      t.string :project, null: false
      t.integer :from_seq, null: false
      t.integer :to_seq, null: false
      t.integer :status, null: false, default: 0
      t.jsonb :required_frames, null: false, default: []
      t.jsonb :spot_check_seqs, null: false, default: []
      t.jsonb :stretches, null: false, default: []
      t.jsonb :spot_checks, null: false, default: []
      t.jsonb :flags, null: false, default: []
      t.integer :claimed_seconds, null: false, default: 0
      t.integer :scored_seconds, null: false, default: 0
      t.integer :ceiling_seconds
      t.integer :credited_seconds, null: false, default: 0
      t.integer :approved_seconds
      t.float :confidence
      t.string :scorer
      t.text :summary
      t.text :reviewer_question
      t.text :user_answer
      t.text :decision_reason
      t.text :appeal
      t.datetime :submitted_at
      t.datetime :decided_at
      t.timestamps
    end
    add_index :evidence_ships, [ :status, :submitted_at ]
  end
end
