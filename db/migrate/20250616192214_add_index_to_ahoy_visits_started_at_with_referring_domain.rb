class AddIndexToAhoyVisitsStartedAtWithReferringDomain < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :ahoy_visits, :started_at,
              where: 'referring_domain IS NOT NULL',
              algorithm: :concurrently,
              name: 'index_ahoy_visits_started_at_with_referring_domain'
  end
end
