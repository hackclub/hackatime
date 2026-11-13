class MakeUsersHCAIdIndexUnique < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_invalid_index "index_users_on_hca_id_unique"
    add_index :users,
              :hca_id,
              unique: true,
              where: "hca_id IS NOT NULL",
              name: "index_users_on_hca_id_unique",
              algorithm: :concurrently,
              if_not_exists: true
    remove_index :users, name: "index_users_on_hca_id", algorithm: :concurrently, if_exists: true
  end

  def down
    remove_invalid_index "index_users_on_hca_id"
    add_index :users, :hca_id, name: "index_users_on_hca_id", algorithm: :concurrently, if_not_exists: true
    remove_index :users, name: "index_users_on_hca_id_unique", algorithm: :concurrently, if_exists: true
  end

  private

  # An interrupted concurrent build leaves an invalid index under the same name,
  # which if_not_exists would then accept as built.
  def remove_invalid_index(name)
    invalid = select_value(<<~SQL)
      SELECT 1 FROM pg_index WHERE indexrelid = to_regclass(#{quote(name)}) AND NOT indisvalid
    SQL
    remove_index :users, name:, algorithm: :concurrently if invalid
  end
end
