class CreateEvidenceBeacons < ActiveRecord::Migration[8.1]
  def change
    create_table :evidence_beacons do |t|
      t.bigint :minute, null: false
      t.string :value, null: false
      t.string :commitment, null: false
      t.text :secret, null: false
      t.datetime :created_at, null: false
    end
    add_index :evidence_beacons, :minute, unique: true
  end
end
