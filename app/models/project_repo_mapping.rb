class ProjectRepoMapping < ApplicationRecord
  IGNORED_PROJECTS = [ nil, "", "<<LAST_PROJECT>>" ].freeze

  belongs_to :user
  belongs_to :repository, optional: true

  has_paper_trail

  validates :project_name, presence: true, uniqueness: { scope: :user_id }
  validates :repo_url, presence: true, if: :repo_url_required?
  validates :repo_url, format: {
    with: %r{\A(https?://[^/]+/[^/]+/[^/]+)\z},
    message: "must be a valid repository URL"
  }, if: :repo_url_required?
  validate :repo_host_supported, if: :repo_url_required?
  validate :repo_url_exists, if: :repo_url_verification_required?

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :all_statuses, -> { unscoped.where(nil) }

  after_create :create_repository_and_sync, if: :repo_url_required?
  after_update :sync_repository_if_url_changed, if: :repo_url_required?

  # Each user's most recently coded project (direct heartbeats in the last five
  # minutes) that has an active mapping: { user_id => ProjectRepoMapping }.
  def self.currently_active_by_user
    Rails.cache.fetch("project_repo_mappings/currently_active_by_user", expires_in: Heartbeat::SITE_ACTIVITY_CACHE_TTL) do
      recent = Heartbeat.where(source_type: :direct_entry).where("time > ?", 5.minutes.ago.to_f)
        .where.not(project: nil).group(:user_id, :project)
        .pluck(:user_id, :project, Arel.sql("max(time)"))
      next {} if recent.empty?

      mappings = active.joins(:user)
        .where(user_id: recent.map(&:first).uniq, project_name: recent.map(&:second).uniq)
        .index_by { |mapping| [ mapping.user_id, mapping.project_name ] }

      recent.sort_by { |_, _, time| -time }.each_with_object({}) do |(user_id, project, _), result|
        mapping = mappings[[ user_id, project ]]
        result[user_id] ||= mapping if mapping
      end
    end
  end

  def repo_url_required? = repo_url.present?
  def archive! = update_archive_status(Time.current)
  def unarchive! = update_archive_status(nil)
  def archived? = archived_at.present?

  private

  def update_archive_status(archived_at)
    update!(archived_at: archived_at)
    DashboardRollupRefreshJob.schedule_for(user_id, wait: 0.seconds)
    true
  end

  def repo_host_supported
    host = RepoHost::ServiceFactory.host_for_url(repo_url)
    unless host && RepoHost::ServiceFactory.supported_hosts.include?(host)
      errors.add(:repo_url, "We only support GitHub repositories")
    end
  end

  def repo_url_verification_required?
    repo_url_required? && (new_record? || will_save_change_to_repo_url?)
  end

  def repo_url_exists
    return if errors[:repo_url].any?

    exists = RepoHost::ServiceFactory.for_url(user, repo_url).repository_exists?
    errors.add(:repo_url, "does not exist or is not accessible") if exists == false
  end

  def create_repository_and_sync
    repo = Repository.find_or_create_by_url(repo_url)
    update_column(:repository_id, repo.id)
    schedule_commit_pull
    SyncRepoMetadataJob.perform_later(repo.id)
  end

  def sync_repository_if_url_changed
    return unless saved_change_to_repo_url?
    repo = Repository.find_or_create_by_url(repo_url)
    update_column(:repository_id, repo.id)
    SyncRepoMetadataJob.perform_later(repo.id)
  end

  def schedule_commit_pull
    return unless repo_url =~ %r{https?://[^/]+/([^/]+)/([^/]+)\z}
    Rails.logger.info "[ProjectRepoMapping] Scheduling commit pull for #{$1}/#{$2} for User ##{user_id}"
    PullRepoCommitsJob.perform_now(user_id, $1, $2)
  end
end
