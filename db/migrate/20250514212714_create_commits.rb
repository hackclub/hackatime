class CreateCommits < ActiveRecord::Migration[8.0]
  def change
    create_table :commits, primary_key: :sha, id: :string do |t|
      t.references :user, null: false, foreign_key: true
      t.jsonb :github_raw

      t.timestamps null: false
    end
  end
end
