require "test_helper"

class WakatimeServiceSummaryTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.clear
    @user = User.create!(username: "wts_#{SecureRandom.hex(4)}")
  end

  teardown do
    Rails.cache.clear
    Rails.cache = @original_cache
  end

  test "generate_summary uses cache when allowed" do
    base = Time.current.beginning_of_day.to_i
    create_heartbeat(project: "cached", language: "Ruby", time: base)
    create_heartbeat(project: "cached", language: "Ruby", time: base + 60)

    first_summary = summary_for(allow_cache: true)

    create_heartbeat(project: "cached", language: "Ruby", time: base + 120)

    cached_summary = summary_for(allow_cache: true)
    fresh_summary = summary_for(allow_cache: false)

    assert_equal first_summary[:total_seconds], cached_summary[:total_seconds]
    assert_operator fresh_summary[:total_seconds], :>, cached_summary[:total_seconds]
  end

  private

  def summary_for(allow_cache:)
    WakatimeService.new(
      user: @user,
      specific_filters: [ :languages, :projects ],
      allow_cache: allow_cache,
      limit: nil,
      start_date: Time.current.beginning_of_day,
      end_date: Time.current.end_of_day
    ).generate_summary
  end

  def create_heartbeat(project:, language:, time:)
    @user.heartbeats.create!(
      entity: "src/main.rb",
      type: "file",
      category: "coding",
      editor: "vscode",
      language: language,
      time: time,
      project: project,
      source_type: :test_entry
    )
  end
end
