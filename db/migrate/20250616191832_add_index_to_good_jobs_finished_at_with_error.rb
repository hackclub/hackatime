class AddIndexToGoodJobsFinishedAtWithError < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :good_jobs, :finished_at,
              where: 'error IS NOT NULL',
              algorithm: :concurrently,
              name: 'index_good_jobs_finished_at_with_error'
  end
end
