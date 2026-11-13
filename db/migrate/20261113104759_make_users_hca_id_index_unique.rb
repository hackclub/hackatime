class MakeUsersHCAIdIndexUnique < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :users,
              :hca_id,
              unique: true,
              where: "hca_id IS NOT NULL",
              name: "index_users_on_hca_id_unique",
              algorithm: :concurrently,
              if_not_exists: true
    remove_index :users,
                 :hca_id,
                 name: "index_users_on_hca_id",
                 algorithm: :concurrently,
                 if_exists: true
  end
end
