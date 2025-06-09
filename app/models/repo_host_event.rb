class RepoHostEvent < ApplicationRecord
  belongs_to :user

  # Tell ActiveRecord to use 'id' as the primary key, even though it's a string.
  self.primary_key = :id

  enum :provider, { github: 0, gitlab: 1 }

  # Validations
  validates :id, presence: true, uniqueness: true
  validates :raw_event_payload, presence: true
  validates :provider, presence: true
  validates :created_at, presence: true # This is the event's occurrence time from the provider

  # Ensure ID starts with a recognized provider prefix
  validates :id, format: {
    with: /\A(gh|gl)_.+\z/, # Allow gh_ or gl_ prefixes
    message: "must start with a provider prefix (e.g., gh_ or gl_)"
  }

  # Helper scope
  scope :for_user_and_provider, ->(user, provider_name) {
    where(user: user, provider: providers[provider_name.to_sym])
  }

  # Helper to construct the prefixed ID
  def self.construct_event_id(provider_name, original_event_id)
    prefix = case provider_name.to_sym
    when :github then "gh_"
    when :gitlab then "gl_" # Example for future
    else
               raise ArgumentError, "Unknown provider: #{provider_name}"
    end
    "#{prefix}#{original_event_id}"
  end
end
