class AddRepositoryToCommits < ActiveRecord::Migration[8.0]
  def change
    add_reference :commits, :repository, null: true, foreign_key: true
  end
end
