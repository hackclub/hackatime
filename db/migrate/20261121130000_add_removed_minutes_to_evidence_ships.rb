class AddRemovedMinutesToEvidenceShips < ActiveRecord::Migration[8.1]
  def change
    add_column :evidence_ships, :excluded_ranges, :jsonb, default: [], null: false
    add_column :evidence_ships, :asked_spot_check_seqs, :jsonb, default: [], null: false
    add_column :evidence_ships, :removed_checks, :integer, default: 0, null: false
    add_column :evidence_blocks, :revealed_at, :datetime
  end
end
