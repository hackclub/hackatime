class Commit < ApplicationRecord
  # Explicitly set 'sha' as the primary key for ActiveRecord.
  # This is crucial because we defined it as such in the migration.
  self.primary_key = :sha

  belongs_to :user
  belongs_to :repository, optional: true

  validates :sha, presence: true, uniqueness: true
  validates :user_id, presence: true
  # `github_raw` could be validated for presence if a commit record implies it must have GitHub data.
  # validates :github_raw, presence: true

  # Note on timestamps:
  # Rails will automatically manage `updated_at`.
  # We will manually set `created_at` when creating a record,
  # based on the `committer.date` from the API.
end
