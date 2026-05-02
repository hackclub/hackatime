if Rails.env.development?
  module DevelopmentSqlLogFilter
    GOOD_JOB_TABLE_PATTERN = /\A\s*(?:WITH\b.*?\bFROM|SELECT\b.*?\bFROM|INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+"good_job(?:s|_[^"]+)"/im
    FRAMEWORK_SQL_PATTERN = /\A\s*(?:BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE SAVEPOINT|SET\b|LISTEN\b|UNLISTEN\b|SELECT\s+"schema_migrations"\.)/i

    def sql(event)
      payload = event.payload
      sql = payload[:sql].to_s

      return if payload[:name].to_s.start_with?("GoodJob::")
      return if sql.include?("job='")
      return if sql.match?(FRAMEWORK_SQL_PATTERN)
      return if sql.match?(GOOD_JOB_TABLE_PATTERN)

      super
    end
  end

  ActiveSupport.on_load(:active_record) do
    ActiveRecord::LogSubscriber.prepend(DevelopmentSqlLogFilter)
  end
end
