class CreateFollows < ActiveRecord::Migration[8.0]
  def change
    create_table :follows do |t|
      t.boolean :ignored, null: false, default: false
      t.belongs_to :from, null: false, foreign_key: { to_table: :users }
      t.belongs_to :to, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :follows, [ :from_id, :to_id ], unique: true
  end
end
