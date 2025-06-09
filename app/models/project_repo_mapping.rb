class ProjectRepoMapping < ApplicationRecord
  belongs_to :user
  belongs_to :repository, optional: true

  has_paper_trail

  validates :project_name, presence: true
  validates :repo_url, presence: true
  validates :project_name, uniqueness: { scope: :user_id }

  validates :repo_url, format: {
    with: %r{\A(https?://[^/]+/[^/]+/[^/]+)\z},
    message: "must be a valid repository URL"
  }

  validate :repo_url_exists

  IGNORED_PROJECTS = [
    nil,
    "",
    "<<LAST PROJECT>>"
  ]

  after_create :create_repository_and_sync
  after_update :sync_repository_if_url_changed

  private

  def repo_url_exists
    unless GitRemote.check_remote_exists(repo_url)
      errors.add(:repo_url, "is not cloneable")
    end
  end

  def create_repository_and_sync
    # Create or find repository record
    repo = Repository.find_or_create_by_url(repo_url)
    update_column(:repository_id, repo.id)

    # Schedule commit pull and metadata sync
    schedule_commit_pull
    SyncRepoMetadataJob.perform_later(repo.id)
  end

  def sync_repository_if_url_changed
    if saved_change_to_repo_url?
      repo = Repository.find_or_create_by_url(repo_url)
      update_column(:repository_id, repo.id)
      SyncRepoMetadataJob.perform_later(repo.id)
    end
  end

  def schedule_commit_pull
    # Extract owner and repo name from the URL
    # Example URL: https://github.com/owner/repo
    if repo_url =~ %r{https?://[^/]+/([^/]+)/([^/]+)\z}
      owner = $1
      repo = $2
      Rails.logger.info "[ProjectRepoMapping] Scheduling commit pull for #{owner}/#{repo} for User ##{user_id}"
      PullRepoCommitsJob.perform_now(user_id, owner, repo)
    end
  end
end
