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

  # Get owner/repo format (e.g., "hackclub/hackatime")
  def full_path
    "#{owner}/#{name}"
  end

  # Get formatted languages list
  def formatted_languages
    return nil if languages.blank?
    languages.split(", ").first(3).join(", ") + (languages.split(", ").length > 3 ? "..." : "")
  end

  # Parse owner and repo from URL
  def self.parse_url(url)
    uri = URI.parse(url)
    path_parts = uri.path.to_s.split("/").reject(&:blank?)

    raise ArgumentError, "Invalid repository URL format: #{url}" if uri.host.blank? || path_parts.size < 2

    {
      host: uri.host,
      owner: path_parts[0...-1].join("/"),
      name: path_parts.last
    }
  rescue URI::InvalidURIError
    raise ArgumentError, "Invalid repository URL format: #{url}"
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
