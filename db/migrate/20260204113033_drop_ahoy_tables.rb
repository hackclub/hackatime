class DropAhoyTables < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Drop indexes concurrently first to avoid locking
    if table_exists?(:ahoy_events)
      remove_index :ahoy_events, name: "index_ahoy_events_on_name_and_time", algorithm: :concurrently if index_exists?(:ahoy_events, name: "index_ahoy_events_on_name_and_time")
      remove_index :ahoy_events, name: "index_ahoy_events_on_properties", algorithm: :concurrently if index_exists?(:ahoy_events, name: "index_ahoy_events_on_properties")
      remove_index :ahoy_events, name: "index_ahoy_events_on_time", algorithm: :concurrently if index_exists?(:ahoy_events, name: "index_ahoy_events_on_time")
      remove_index :ahoy_events, name: "index_ahoy_events_on_user_id", algorithm: :concurrently if index_exists?(:ahoy_events, name: "index_ahoy_events_on_user_id")
      remove_index :ahoy_events, name: "index_ahoy_events_on_visit_id", algorithm: :concurrently if index_exists?(:ahoy_events, name: "index_ahoy_events_on_visit_id")
    end

    if table_exists?(:ahoy_visits)
      remove_index :ahoy_visits, name: "index_ahoy_visits_on_started_at", algorithm: :concurrently if index_exists?(:ahoy_visits, name: "index_ahoy_visits_on_started_at")
      remove_index :ahoy_visits, name: "index_ahoy_visits_started_at_with_referring_domain", algorithm: :concurrently if index_exists?(:ahoy_visits, name: "index_ahoy_visits_started_at_with_referring_domain")
      remove_index :ahoy_visits, name: "index_ahoy_visits_on_user_id", algorithm: :concurrently if index_exists?(:ahoy_visits, name: "index_ahoy_visits_on_user_id")
      remove_index :ahoy_visits, name: "index_ahoy_visits_on_visit_token", algorithm: :concurrently if index_exists?(:ahoy_visits, name: "index_ahoy_visits_on_visit_token")
      remove_index :ahoy_visits, name: "index_ahoy_visits_on_visitor_token_and_started_at", algorithm: :concurrently if index_exists?(:ahoy_visits, name: "index_ahoy_visits_on_visitor_token_and_started_at")
    end

    # Drop tables (events first due to FK constraint)
    drop_table :ahoy_events if table_exists?(:ahoy_events)
    drop_table :ahoy_visits if table_exists?(:ahoy_visits)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
