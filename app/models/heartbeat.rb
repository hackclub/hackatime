class Heartbeat < ApplicationRecord
  before_save :set_fields_hash!
  before_save :set_time_epoch!
  after_commit :mirror_to_clickhouse, on: %i[create update], unless: -> { Rails.env.test? }
  after_save :mirror_to_clickhouse, if: -> { Rails.env.test? }

  include Heartbeatable
  include TimeRangeFilterable

  time_range_filterable_field :time

  # Default scope to exclude deleted records
  default_scope { where(deleted_at: nil) }

  scope :today, -> { where(time: Time.current.beginning_of_day.to_i..Time.current.end_of_day.to_i) }
  scope :recent, -> { where("time > ?", 24.hours.ago.to_i) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :only_deleted, -> { with_deleted.where.not(deleted_at: nil) }

  enum :source_type, {
    direct_entry: 0,
    wakapi_import: 1,
    test_entry: 2
  }

  # This is to prevent Rails from trying to use STI even though we have a "type" column
  self.inheritance_column = nil

  self.ignored_columns += %w[ysws_program] # unused

  belongs_to :user
  belongs_to :ja4, optional: true

  validates :time, presence: true

  # after_create :mirror_to_wakatime

  def self.recent_count = Cache::HeartbeatCountsJob.perform_now[:recent_count]
  def self.recent_imported_count = Cache::HeartbeatCountsJob.perform_now[:recent_imported_count]

  def self.generate_fields_hash(attributes)
    Digest::MD5.hexdigest(attributes.transform_keys(&:to_s).slice(*self.indexed_attributes).to_json)
  end

  def self.indexed_attributes
    %w[user_id branch category dependencies editor entity language machine operating_system project type user_agent line_additions line_deletions lineno lines cursorpos project_root_count time is_write]
  end

  def soft_delete
    update_column(:deleted_at, Time.current)
    mirror_to_clickhouse
  end

  def restore
    # updated_at bump required: the ClickHouse row version is max(updated_at, deleted_at)
    update_columns(deleted_at: nil, updated_at: Time.current)
    mirror_to_clickhouse
  end

  private

  def mirror_to_clickhouse
    return unless Clickhouse::HeartbeatMirror.enabled?

    Clickhouse::HeartbeatMirror.upsert(self)
  rescue => e
    Rails.logger.error "ClickHouse heartbeat mirror failed for heartbeat #{id}: #{e.class}: #{e.message}"
  end

  def set_fields_hash!
    # only if the field exists in activerecord
    self.fields_hash = self.class.generate_fields_hash(self.attributes) if self.class.column_names.include?("fields_hash")
  end

  # Populate the hypertable partition column on AR-object saves. Bulk ingest
  # (insert/insert_all) sets it directly; this covers create/save/update paths.
  # No-op until the column exists (post-cutover; plain table in dev/test).
  def set_time_epoch!
    self.time_epoch = time&.floor if self.class.column_names.include?("time_epoch") && time.present?
  end
end
