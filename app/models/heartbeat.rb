class Heartbeat < ApplicationRecord
  before_save :set_fields_hash!

  include Heartbeatable
  include TimeRangeFilterable
  include PublicActivity::Common

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

  enum :ysws_program, {
    nothing: 0,
    high_seas: 1,
    arcade: 2,
    juice: 3,
    onboard: 4,
    sprig: 5,
    cider: 6,
    hackpad: 7,
    boba_drops: 8,
    the_bin: 9,
    blot: 10,
    infill: 11,
    scrapyard: 12,
    hackcraft_mod_edition: 13,
    browser_buddy: 14,
    hackaccino: 15,
    cafe: 16,
    low_skies: 17,
    rasp_api: 18,
    terminal_craft: 19,
    neon: 20,
    jungle: 21,
    counterspell: 22,
    riceathon: 23,
    power_hour: 24,
    scrapyard_flagship: 25,
    ten_days_in_public: 26,
    build_your_own_llm: 27,
    cargo_cult_v2: 28,
    sockathon: 29,
    bakebuild: 30,
    minus_twelve: 31,
    easel: 32,
    retrospect: 33,
    cascade: 34,
    ten_hours_in_public: 35,
    swirl: 36,
    tarot: 37,
    asylum: 38,
    cargo_cult: 39,
    rpg: 40,
    ham_club: 41,
    anchor: 42,
    dessert: 43,
    wizard_orpheus: 44,
    onboard_live: 45,
    say_cheese: 46,
    hackapet: 47,
    clubs_competitions: 48,
    printboard: 49,
    black_box: 50,
    shipwrecked: 51,
    pizza_grant_ysws: 52,
    pixeldust: 53,
    hacklet: 54,
    reflow: 55,
    the_journey: 56,
    visioneer: 57,
    neighborhood: 58
  }, prefix: :claimed_by

  # This is to prevent Rails from trying to use STI even though we have a "type" column
  self.inheritance_column = nil

  belongs_to :user
  belongs_to :raw_heartbeat_upload, optional: true

  validates :time, presence: true

  # after_create :mirror_to_wakatime

  def self.recent_count
    Cache::HeartbeatCountsJob.perform_now[:recent_count]
  end

  def self.recent_imported_count
    Cache::HeartbeatCountsJob.perform_now[:recent_imported_count]
  end

  def self.generate_fields_hash(attributes)
    string_attributes = attributes.transform_keys(&:to_s)
    indexed_attributes = string_attributes.slice(*self.indexed_attributes)
    Digest::MD5.hexdigest(indexed_attributes.to_json)
  end

  def self.indexed_attributes
    %w[user_id branch category dependencies editor entity language machine operating_system project type user_agent line_additions line_deletions lineno lines cursorpos project_root_count time is_write]
  end

  def soft_delete
    update_column(:deleted_at, Time.current)
  end

  def restore
    update_column(:deleted_at, nil)
  end

  private

  def set_fields_hash!
    # only if the field exists in activerecord
    if self.class.column_names.include?("fields_hash")
      self.fields_hash = self.class.generate_fields_hash(self.attributes)
    end
  end

  # def mirror_to_wakatime
  #   WakatimeMirror.mirror_heartbeat(self)
  # end
end
