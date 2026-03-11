class UpdateLapseHeartbeatLanguage < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  BATCH_SIZE = 10_000

  def up
    loop do
      result = execute(<<-SQL.squish)
        UPDATE heartbeats
        SET language = 'Lapse', updated_at = NOW()
        WHERE id IN (
          SELECT id FROM heartbeats
          WHERE user_agent IN (
            'wakatime/lapse (lapse) lapse/2.0.0 lapse/2.0.0',
            'wakatime/lapse (lapse) lapse/0.1.0 lapse/0.1.0'
          )
          AND language IS DISTINCT FROM 'Lapse'
          LIMIT #{BATCH_SIZE}
        )
      SQL

      break if result.cmd_tuples == 0

      sleep(0.1)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
