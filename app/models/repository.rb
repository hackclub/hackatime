class Repository < ApplicationRecord
  has_many :project_repo_mappings, dependent: :destroy
  has_many :users, through: :project_repo_mappings
  has_many :commits, dependent: :destroy

  validates :url, presence: true, uniqueness: true
  validates :host, presence: true
  validates :owner, presence: true
  validates :name, presence: true

  # Check if metadata needs refreshing (older than 1 day)
  def metadata_stale?
    last_synced_at.nil? || last_synced_at < 1.day.ago
  end

  # Get formatted languages list
  def formatted_languages
    return nil if languages.blank?
    languages.split(", ").first(3).join(", ") + (languages.split(", ").length > 3 ? "..." : "")
  end

  # Parse owner and repo from URL
  def self.parse_url(url)
    if url =~ %r{https?://([^/]+)/([^/]+)/([^/]+)/?$}
      {
        host: $1,
        owner: $2,
        name: $3
      }
    else
      raise ArgumentError, "Invalid repository URL format: #{url}"
    end
  end

  # Find or create repository from URL
  def self.find_or_create_by_url(url)
    parsed = parse_url(url)
    find_or_create_by(url: url) do |repo|
      repo.host = parsed[:host]
      repo.owner = parsed[:owner]
      repo.name = parsed[:name]
    end
  end
end
