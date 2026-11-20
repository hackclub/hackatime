class CreateEvidenceViews < ActiveRecord::Migration[8.1]
  def change
    create_table :evidence_views do |t|
      t.references :evidence_ship, null: false, foreign_key: true
      t.references :evidence_frame, foreign_key: true
      t.references :viewer, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.datetime :created_at, null: false
    end
  end
end
