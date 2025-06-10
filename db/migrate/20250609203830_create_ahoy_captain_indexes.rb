class CreateAhoyCaptainIndexes < ActiveRecord::Migration[8.0]
  def change
    add_index :ahoy_visits, :started_at unless index_exists?(:ahoy_visits, :started_at)
    add_index :ahoy_events, :visit_id unless index_exists?(:ahoy_events, :visit_id)
    add_index :ahoy_events, :time unless index_exists?(:ahoy_events, :time)
  end
end
