class AddHeartbeatsUserTimeProjectLanguageCoveringIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :heartbeats, [ :user_id, :time ],
      name: :idx_heartbeats_user_time_project_language,
      where: "deleted_at IS NULL AND project IS NOT NULL AND project <> '' AND language IS NOT NULL AND language <> ''",
      include: [ :project, :language ],
      algorithm: :concurrently,
      if_not_exists: true
  end
end
