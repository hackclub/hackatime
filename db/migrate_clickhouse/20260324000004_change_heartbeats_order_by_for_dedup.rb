class ChangeHeartbeatsOrderByForDedup < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      ALTER TABLE heartbeats
      MODIFY ORDER BY (user_id, toDate(toDateTime(toUInt32(time))), project, entity, time)
    SQL
  end

  def down
    execute <<~SQL
      ALTER TABLE heartbeats
      MODIFY ORDER BY (user_id, toDate(toDateTime(toUInt32(time))), project, id)
    SQL
  end
end
