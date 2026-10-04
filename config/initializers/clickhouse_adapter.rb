# Raw ClickHouse results (select_all / select_rows / select_value / pluck of
# expressions) come back as parsed JSON, where every decimal number is a
# BigDecimal. Postgres returns Floats for float8, and BigDecimals render as
# strings in JSON responses. The adapter already knows each column's type, so
# cast Float columns back to Float. Model attribute reads are unaffected
# (they are cast by the model's attribute types).
module ClickhouseFloatResults
  def internal_exec_query(...)
    result = super
    float_columns = result.columns.each_index.select { |i| result.column_types[i].is_a?(ActiveModel::Type::Float) }
    return result if float_columns.empty?

    rows = result.rows.map do |row|
      row = row.dup
      float_columns.each { |i| row[i] = row[i].to_f unless row[i].nil? }
      row
    end
    ActiveRecord::Result.new(result.columns, rows, result.column_types)
  end
end

ActiveSupport.on_load(:active_record) do
  require "active_record/connection_adapters/clickhouse_adapter"
  ActiveRecord::ConnectionAdapters::ClickhouseAdapter.prepend(ClickhouseFloatResults)
end
