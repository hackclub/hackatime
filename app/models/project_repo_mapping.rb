class ProjectRepoMapping < ApplicationRecord
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

  after_commit :sync_repository, on: [ :create, :update ], if: -> { repo_url_required? && saved_change_to_repo_url? }

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

  def sync_repository
    repo = Repository.find_or_create_by_url(repo_url)
    update_column(:repository_id, repo.id)
    PullRepoCommitsJob.perform_later(user_id, repo.owner, repo.name)
    SyncRepoMetadataJob.perform_later(repo.id)
  end
end
