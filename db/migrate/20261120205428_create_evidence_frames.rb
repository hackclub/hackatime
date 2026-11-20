class CreateEvidenceFrames < ActiveRecord::Migration[8.1]
  def change
    create_table :evidence_frames do |t|
      t.references :evidence_ship, null: false, foreign_key: true
      t.string :frame_hash, null: false
      t.integer :seq, null: false
      t.bigint :captured_at_ms, null: false
      t.string :kind, null: false
      t.string :trigger
      t.boolean :required, null: false, default: false
      t.boolean :redacted, null: false, default: false
      t.jsonb :redactions, null: false, default: []
      t.text :segment_key
      t.timestamps
    end
    add_index :evidence_frames, [ :evidence_ship_id, :frame_hash ], unique: true
  end
end
