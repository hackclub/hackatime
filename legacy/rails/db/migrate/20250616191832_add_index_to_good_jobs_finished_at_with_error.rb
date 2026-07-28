class AddIndexToGoodJobsFinishedAtWithError < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :good_jobs, :finished_at,
              where: 'error IS NOT NULL',
              algorithm: :concurrently,
              name: 'index_good_jobs_finished_at_with_error',
              if_not_exists: true
  end
end
