class HeartbeatImportRun < ApplicationRecord
  COOLDOWN = 8.minutes

  TERMINAL_STATES = %w[completed failed].freeze
  ACTIVE_STATES = %w[queued requesting_dump waiting_for_dump downloading_dump importing].freeze
  REMOTE_SOURCE_KINDS = %w[wakatime_dump hackatime_v1_dump].freeze
  WAKATIME_SOURCE_KINDS = %w[wakatime_dump wakatime_download_link].freeze

  belongs_to :user

  encrypts :encrypted_api_key, deterministic: false

  enum :source_kind, {
    dev_upload: 0,
    wakatime_dump: 1,
    hackatime_v1_dump: 2,
    wakatime_download_link: 3
  }

  enum :state, {
    queued: 0,
    requesting_dump: 1,
    waiting_for_dump: 2,
    downloading_dump: 3,
    importing: 4,
    completed: 5,
    failed: 6
  }

  validates :encrypted_api_key, presence: true, on: :create, if: :remote?

  scope :latest_first, -> { order(created_at: :desc) }
  scope :active_imports, -> { where(state: states.values_at(*ACTIVE_STATES)) }
  scope :remote_imports, -> { where(source_kind: source_kinds.values_at(*REMOTE_SOURCE_KINDS)) }

  def remote?
    REMOTE_SOURCE_KINDS.include?(source_kind)
  end

  def wakatime?
    WAKATIME_SOURCE_KINDS.include?(source_kind)
  end

  def terminal?
    TERMINAL_STATES.include?(state)
  end

  def active_import?
    ACTIVE_STATES.include?(state)
  end

  def cooldown_until
    return nil if remote_requested_at.blank?

    remote_requested_at + COOLDOWN
  end

  def progress_percent
    return 100 if completed?

    if waiting_for_dump? || downloading_dump? || requesting_dump?
      return remote_percent_complete.to_f.clamp(0, 100).round
    end

    return 0 unless total_count.to_i.positive?

    ((processed_count.to_f / total_count.to_f) * 100).clamp(0, 100).round
  end

  def clear_sensitive_fields!
    update_columns(encrypted_api_key: nil, updated_at: Time.current)
  end

  def self.active_for(user)
    where(user: user).active_imports.latest_first.first
  end

  def self.latest_for(user)
    where(user: user).latest_first.first
  end

  def self.remote_cooldown_until_for(user)
    latest_remote_request = where(user: user)
      .remote_imports
      .where.not(remote_requested_at: nil)
      .order(remote_requested_at: :desc)
      .pick(:remote_requested_at)

    return nil if latest_remote_request.blank?

    retry_at = latest_remote_request + COOLDOWN
    retry_at.future? ? retry_at : nil
  end
end
