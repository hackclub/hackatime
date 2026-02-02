class CreateHeartbeatLookupTables < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    create_table :heartbeat_languages do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :heartbeat_languages, :name, unique: true, algorithm: :concurrently

    create_table :heartbeat_categories do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :heartbeat_categories, :name, unique: true, algorithm: :concurrently

    create_table :heartbeat_editors do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :heartbeat_editors, :name, unique: true, algorithm: :concurrently

    create_table :heartbeat_operating_systems do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :heartbeat_operating_systems, :name, unique: true, algorithm: :concurrently

    create_table :heartbeat_user_agents do |t|
      t.string :value, null: false
      t.timestamps
    end
    add_index :heartbeat_user_agents, :value, unique: true, algorithm: :concurrently

    create_table :heartbeat_projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :heartbeat_projects, [ :user_id, :name ], unique: true, algorithm: :concurrently

    create_table :heartbeat_branches do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :heartbeat_branches, [ :user_id, :name ], unique: true, algorithm: :concurrently

    create_table :heartbeat_machines do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
    add_index :heartbeat_machines, [ :user_id, :name ], unique: true, algorithm: :concurrently
  end
end
