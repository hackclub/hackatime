class ProjectRepoMapping < ApplicationRecord
  belongs_to :user

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

  after_create :schedule_commit_pull

  private

  def repo_url_exists
    unless GitRemote.check_remote_exists(repo_url)
      errors.add(:repo_url, "is not cloneable")
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
