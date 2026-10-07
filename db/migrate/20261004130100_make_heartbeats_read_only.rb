# Heartbeats now live in ClickHouse. The Postgres table is kept read-only for
# verification until it is dropped; any write to it is a bug.
#
# The cutover applies the same trigger before deploying (script/clickhouse/cutover.sh),
# which is also what pauses writes from the old app during the final copy.
class MakeHeartbeatsReadOnly < ActiveRecord::Migration[8.1]
  def up
    # Their ON DELETE actions would now write to heartbeats and fail, blocking
    # deletes of JA4 fingerprints and users.
    remove_foreign_key :heartbeats, :ja4s, if_exists: true
    remove_foreign_key :heartbeats, :users, if_exists: true

    execute <<~SQL
      CREATE OR REPLACE FUNCTION heartbeats_read_only() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        RAISE EXCEPTION 'heartbeats is read-only: heartbeats are stored in ClickHouse';
      END
      $$;
      DROP TRIGGER IF EXISTS heartbeats_read_only ON heartbeats;
      CREATE TRIGGER heartbeats_read_only
        BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE ON heartbeats
        FOR EACH STATEMENT EXECUTE FUNCTION heartbeats_read_only();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS heartbeats_read_only ON heartbeats;
      DROP FUNCTION IF EXISTS heartbeats_read_only();
    SQL
    add_foreign_key :heartbeats, :users, if_not_exists: true
    add_foreign_key :heartbeats, :ja4s, on_delete: :nullify, if_not_exists: true
  end
end
