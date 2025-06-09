class CreateRepositories < ActiveRecord::Migration[8.0]
  def change
    create_table :repositories do |t|
      t.string :url
      t.string :host
      t.string :owner
      t.string :name
      t.integer :stars
      t.text :description
      t.string :language
      t.text :languages
      t.integer :commit_count
      t.datetime :last_commit_at
      t.datetime :last_synced_at

      t.timestamps
    end
    add_index :repositories, :url, unique: true
  end
end
