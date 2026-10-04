# Applies the ClickHouse schema in db/clickhouse/*.sql. These files are the
# source of truth for ClickHouse tables (Rails migrations only manage Postgres).
#
# Each file is idempotent (CREATE ... IF NOT EXISTS) and is applied in filename
# order. Statements are split on semicolons at the end of a line.
module ClickhouseSchema
  SCHEMA_DIR = Rails.root.join("db/clickhouse")

  module_function

  def statements
    SCHEMA_DIR.glob("*.sql").sort.flat_map do |path|
      path.read.split(/;\s*$/).map { |sql| strip_comments(sql) }.reject(&:blank?)
    end
  end

  # Creates every table in the connection's current database. The database
  # itself must already exist (the adapter selects it on every request).
  def load!(connection = ClickhouseRecord.connection)
    statements.each { |sql| connection.execute(sql) }
  end

  def table_names = statements.filter_map { |sql| sql[/CREATE TABLE IF NOT EXISTS\s+`?(\w+)`?/i, 1] }

  def strip_comments(sql)
    sql.lines.reject { |line| line.strip.start_with?("--") }.join.strip
  end
end
