require "test_helper"

class SiteActivityCacheJobTest < ActiveJob::TestCase
  test "refreshes the site-wide activity caches" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache.lookup_store(:memory_store)
    user = create(:user)
    Rails.cache.write("currently_hacking/count", 0)
    create(:heartbeat, user:, time: 1.minute.ago.to_f, category: "coding", source_type: :direct_entry)

    SiteActivityCacheJob.perform_now

    assert_equal 1, Rails.cache.read("currently_hacking/count")
    %w[heartbeats/recent_counts heartbeats/active_users_by_hour heartbeats/minutes_logged_last_hour
       currently_hacking/data project_repo_mappings/currently_active_by_user heartbeat_rollups/site_totals].each do |key|
      assert Rails.cache.exist?(key), "expected #{key} to be cached"
    end
  ensure
    Rails.cache = original_cache
  end
end
