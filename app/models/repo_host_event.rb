class RepoHostEvent < ApplicationRecord
  PROVIDER_PREFIXES = { github: "gh_", gitlab: "gl_" }.freeze

  belongs_to :user
  self.primary_key = :id

  enum :provider, { github: 0, gitlab: 1 }

  validates :id, presence: true, uniqueness: true,
                 format: { with: /\A(gh|gl)_.+\z/, message: "must start with a provider prefix (e.g., gh_ or gl_)" }
  validates :raw_event_payload, :provider, :created_at, presence: true

  scope :for_user_and_provider, ->(user, provider_name) {
    where(user: user, provider: providers[provider_name.to_sym])
  }

  def self.construct_event_id(provider_name, original_event_id)
    prefix = PROVIDER_PREFIXES[provider_name.to_sym] || raise(ArgumentError, "Unknown provider: #{provider_name}")
    "#{prefix}#{original_event_id}"
  end
end
