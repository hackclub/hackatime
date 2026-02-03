# The Big Migration(tm)

## Run DB migrations

```bash
rails db:migrate
```

## Start dual-writing

```ruby
Flipper.enable(:heartbeat_dimension_dual_write)
```

## Backfill the data

Run the backfill rake task to populate FK columns for existing heartbeats:

```bash
rails heartbeats:backfill_dimensions
```

For progress:

```bash
rails heartbeats:backfill_progress
```

## Validate FKs

AFTER the backfill is complete (100% progress on all dimensions), generate and run:

```bash
rails g migration ValidateHeartbeatForeignKeys
rails db:migrate
```

Migration content:

```ruby
class ValidateHeartbeatForeignKeys < ActiveRecord::Migration[8.1]
  def up
    validate_foreign_key :heartbeats, :heartbeat_languages
    validate_foreign_key :heartbeats, :heartbeat_categories
    validate_foreign_key :heartbeats, :heartbeat_editors
    validate_foreign_key :heartbeats, :heartbeat_operating_systems
    validate_foreign_key :heartbeats, :heartbeat_user_agents
    validate_foreign_key :heartbeats, :heartbeat_projects
    validate_foreign_key :heartbeats, :heartbeat_branches
    validate_foreign_key :heartbeats, :heartbeat_machines
  end

  def down
  end
end
```

(we don't have these in `migrations` bc it won't work till the backfill is done)

### Stop writing raw_data

```ruby
Flipper.enable(:skip_heartbeat_raw_data)
```

### Remove raw_data Column

**WARNING:** This will lock the DB!! We'll need to co-ordinate an announcement with program owners + the wider Slack

```bash
rails g migration RemoveRawDataFromHeartbeats
rails db:migrate
```

Migration content:

```ruby
class RemoveRawDataFromHeartbeats < ActiveRecord::Migration[8.1]
  def up
    remove_column :heartbeats, :raw_data
  end

  def down
    add_column :heartbeats, :raw_data, :jsonb
  end
end
```

## Rollback plan

```ruby
Flipper.disable(:heartbeat_dimension_dual_write)
```

## Future stuff

(Once the migration is done)

### Read cutover

Update read queries to:

1. Filter/GROUP BY FK columns instead of string columns
2. JOIN to lookup tables only for display names

## Time partitioning

For leaderboards etc!
