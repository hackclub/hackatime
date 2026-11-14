class AddUniqueLowerUsernameIndexToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  INDEX_NAME = "index_users_on_lower_username_unique"

  def up
    remove_invalid_index
    add_index :users, "LOWER(username)",
              unique: true,
              name: INDEX_NAME,
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :users, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end

  private

  # An interrupted concurrent build leaves an invalid index under the same name,
  # which if_not_exists would then accept as built.
  def remove_invalid_index
    invalid = select_value(<<~SQL)
      SELECT 1 FROM pg_index WHERE indexrelid = to_regclass(#{quote(INDEX_NAME)}) AND NOT indisvalid
    SQL
    remove_index :users, name: INDEX_NAME, algorithm: :concurrently if invalid
  end
end
