class ProjectRepoMapping < ApplicationRecord
  IGNORED_PROJECTS = [ nil, "", "<<LAST PROJECT>>" ]

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
  validate :repo_url_exists, if: :repo_url_required?

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :all_statuses, -> { unscoped.where(nil) }

  after_create :create_repository_and_sync, if: :repo_url_required?
  after_update :sync_repository_if_url_changed, if: :repo_url_required?

  def repo_url_required? = repo_url.present?
  def archive! = update_column(:archived_at, Time.current)
  def unarchive! = update_column(:archived_at, nil)
  def archived? = archived_at.present?

  private

  def repo_host_supported
    host = RepoHost::ServiceFactory.host_for_url(repo_url)
    unless host && RepoHost::ServiceFactory.supported_hosts.include?(host)
      errors.add(:repo_url, "We only support GitHub repositories")
    end
  end

  def repo_url_exists
    errors.add(:repo_url, "is not cloneable") unless GitRemote.check_remote_exists(repo_url)
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
