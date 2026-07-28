class AddRecommendedQueryIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :dashboard_rollups, :bucket_value,
      name: :index_dashboard_rollups_on_bucket_value,
      algorithm: :concurrently,
      if_not_exists: true

    add_index :users, :hca_id,
      name: :index_users_on_hca_id,
      algorithm: :concurrently,
      if_not_exists: true

    add_index :leaderboards, :start_date,
      name: :index_leaderboards_on_start_date_all,
      algorithm: :concurrently,
      if_not_exists: true

    add_index :good_jobs, :scheduled_at,
      name: :index_good_jobs_on_scheduled_at_all,
      algorithm: :concurrently,
      if_not_exists: true

    add_index :good_jobs, :scheduled_at,
      name: :index_good_jobs_on_scheduled_at_unfinished_unperformed,
      where: "finished_at IS NULL AND performed_at IS NULL",
      algorithm: :concurrently,
      if_not_exists: true
  end
end
