class Repository < ApplicationRecord
  has_many :project_repo_mappings, dependent: :destroy
  has_many :users, through: :project_repo_mappings
  has_many :commits, dependent: :destroy

  validates :url, presence: true, uniqueness: true
  validates :host, :owner, :name, presence: true

  def metadata_stale? = last_synced_at.nil? || last_synced_at < 1.day.ago
  def full_path = "#{owner}/#{name}"

  def formatted_languages
    return nil if languages.blank?
    parts = languages.split(", ")
    parts.first(3).join(", ") + (parts.length > 3 ? "..." : "")
  end

  def self.parse_url(url)
    raise ArgumentError, "Invalid repository URL format: #{url}" unless url =~ %r{https?://([^/]+)/([^/]+)/([^/]+)/?$}
    { host: $1, owner: $2, name: $3 }
  end

  def self.find_or_create_by_url(url)
    parsed = parse_url(url)
    find_or_create_by(url: url) do |repo|
      repo.host = parsed[:host]
      repo.owner = parsed[:owner]
      repo.name = parsed[:name]
    end
  end
end
