class HeartbeatRow
  COLUMNS = %w[
    id user_id time project branch entity category editor language machine operating_system type
    user_agent ip_address dependencies lineno lines cursorpos line_additions line_deletions
    project_root_count is_write source_type ysws_program ja4_id ai_model ai_session
    ai_subscription_plan ai_input_tokens ai_output_tokens ai_prompt_length ai_line_changes
    human_line_changes deleted_at created_at updated_at
  ].freeze
  ATTRIBUTES = [ *COLUMNS, "fields_hash" ].freeze
  INTEGER_COLUMNS = %w[
    id user_id lineno lines cursorpos line_additions line_deletions project_root_count ysws_program
    ja4_id ai_input_tokens ai_output_tokens ai_prompt_length ai_line_changes human_line_changes
  ].freeze
  DATETIME_COLUMNS = %w[deleted_at created_at updated_at].freeze

  attr_reader :attributes

  def self.from_input(attributes)
    values = COLUMNS.index_with { nil }.merge(attributes.stringify_keys.slice(*COLUMNS))
    values["source_type"] = Heartbeat.source_types.fetch(values["source_type"].to_s, values["source_type"])
    values["ysws_program"] ||= 0
    new(values)
  end

  def self.deserialize(column, value)
    return if value.nil?
    return Heartbeat.source_types.key(value.to_i) || value if column == "source_type"
    return IPAddr.new(value) if column == "ip_address"
    return ActiveModel::Type::Boolean.new.deserialize(value) if column == "is_write"
    return ActiveModel::Type::Integer.new.deserialize(value) if INTEGER_COLUMNS.include?(column)
    return ActiveModel::Type::Float.new.deserialize(value) if column == "time"
    return Time.zone.parse(value.to_s) if DATETIME_COLUMNS.include?(column)

    value
  end

  def initialize(attributes)
    @attributes = attributes.stringify_keys.slice(*ATTRIBUTES).to_h do |column, value|
      [ column, self.class.deserialize(column, value) ]
    end
  end

  ATTRIBUTES.each { |column| define_method(column) { attributes[column] } }

  def as_json(options = nil) = attributes.as_json(options)

  def soft_delete
    HeartbeatRepository.current.change_deleted(heartbeat_id: id, user_id:, deleted: true)
    attributes["deleted_at"] = Time.current
    self
  end

  def restore
    HeartbeatRepository.current.change_deleted(heartbeat_id: id, user_id:, deleted: false)
    attributes["deleted_at"] = nil
    self
  end
end
