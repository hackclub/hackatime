class CreateRepoHostEvents < ActiveRecord::Migration[8.0]
  def change
    # id: false because we are defining a custom string primary key 'id'
    create_table :repo_host_events, id: false do |t|
      t.string :id, null: false, primary_key: true # Custom PK: e.g., gh_eventid123
      t.references :user, null: false, foreign_key: true
      t.jsonb :raw_event_payload, null: false # Stores the actual event content from GitHub
      t.integer :provider, null: false, default: 0 # 0 for GitHub

      # Per prompt: "created_at is created_at from gh json"
      # This means the AR `created_at` field will store the event's timestamp from GitHub.
      # Rails' `updated_at` will track when our DB record was last modified.
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    # Add an index on provider for filtering
    add_index :repo_host_events, :provider
    # Add an index for efficiently finding the latest event for a user/provider,
    # and for the "stop fetching if event exists" logic.
    # The primary key `id` is already unique and indexed.
    add_index :repo_host_events, [ :user_id, :provider, :created_at ], name: 'index_repo_host_events_on_user_provider_created_at'
  end
end
