# frozen_string_literal: true

module Inertia
  class FooterSerializer < BaseSerializer
    attribute :git_version, type: :string
    attribute :commit_link, type: :string
    attribute :server_start_time_ago, type: :string
    attribute :heartbeat_recent_count, type: :number
    attribute :heartbeat_recent_imported_count, type: :number
    attribute :query_count, type: :number
    attribute :query_cache_count, type: :number
    attribute :cache_hits, type: :number
    attribute :cache_misses, type: :number
    attribute :requests_per_second, type: :string
    has_many :active_users_graph, serializer: Inertia::ActiveUsersGraphEntrySerializer
  end
end
