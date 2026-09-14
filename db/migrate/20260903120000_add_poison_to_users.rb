class AddPoisonToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :poisoned_until, :datetime
    add_column :users, :poisoned_at, :datetime
    add_column :users, :poison_reason, :text

    add_index :users, :poisoned_until, where: "poisoned_until IS NOT NULL"
  end
end
