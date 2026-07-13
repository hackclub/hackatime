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

  test "default date range is scoped to the requested user" do
    other_user = User.create!(username: "wts_other_#{SecureRandom.hex(4)}")
    other_old_time = 30.days.ago.beginning_of_day.to_i
    create_heartbeat_for(other_user, project: "other", language: "Ruby", time: other_old_time)
    create_heartbeat_for(other_user, project: "other", language: "Ruby", time: other_old_time + 60)

    base = Time.current.beginning_of_day.to_i
    create_heartbeat(project: "scoped", language: "Ruby", time: base)
    create_heartbeat(project: "scoped", language: "Ruby", time: base + 60)
    create_heartbeat(project: "scoped", language: "Ruby", time: base + 120)

    summary = WakatimeService.new(user: @user, allow_cache: false, limit: nil).generate_summary

    assert_equal Time.at(base).strftime("%Y-%m-%dT%H:%M:%SZ"), summary[:start]
    assert_equal Time.at(base + 120).strftime("%Y-%m-%dT%H:%M:%SZ"), summary[:end]
    assert_equal 60, summary[:total_seconds]
  end

  test "whole-day summary uses serving tables for totals and breakdowns" do
    base = Time.utc(2026, 7, 10, 12)
    create_heartbeat(project: "served", language: "Ruby", time: base.to_f)
    create_heartbeat(project: "served", language: "Python", time: (base + 60.seconds).to_f)
    create_heartbeat(project: "served", language: "Ruby", time: (base + 120.seconds).to_f)
    raw_queries = []
    serving_queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      raw_queries << payload[:sql] if payload[:sql].to_s.match?(/\bFROM\s+heartbeats\b/i)
    end
    serving_subscriber = ActiveSupport::Notifications.subscribe("sql.clickhouse_serving") do |*, payload|
      serving_queries << payload.fetch(:sql)
    end

    summary = WakatimeService.new(
      user: @user,
      specific_filters: %i[languages projects],
      allow_cache: false,
      limit: nil,
      start_date: base.beginning_of_day,
      end_date: base.end_of_day
    ).generate_summary

    assert_equal 120, summary[:total_seconds]
    assert_equal({ "Ruby" => 120, "Python" => 0 }, summary[:languages].to_h { |row| [ row[:name], row[:total_seconds] ] })
    assert_equal({ "served" => 120 }, summary[:projects].to_h { |row| [ row[:name], row[:total_seconds] ] })
    assert_empty raw_queries
    assert_equal 2, serving_queries.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    ActiveSupport::Notifications.unsubscribe(serving_subscriber) if serving_subscriber
  end

  test "project-scoped whole-day summary uses project attribution" do
    base = Time.utc(2026, 7, 10, 12)
    create_heartbeat(project: "selected", language: "Ruby", time: base.to_f)
    create_heartbeat(project: "other", language: "Go", time: (base + 30.seconds).to_f)
    create_heartbeat(project: "selected", language: "Python", time: (base + 60.seconds).to_f)

    scope = Clickhouse::Heartbeat.for_user(@user).where(project: "selected")
    summary = WakatimeService.new(
      user: @user,
      scope: scope,
      serving_filters: { project: "selected" },
      specific_filters: %i[languages projects],
      allow_cache: false,
      limit: nil,
      start_date: base.beginning_of_day,
      end_date: base.end_of_day
    ).generate_summary

    assert_equal 60, summary[:total_seconds]
    assert_equal [ [ "Python", 0 ], [ "Ruby", 0 ] ], summary[:languages].map { |row| [ row[:name], row[:total_seconds] ] }
    assert_equal [ [ "selected", 60 ] ], summary[:projects].map { |row| [ row[:name], row[:total_seconds] ] }
  end

  test "language-only serving summary uses one fused query" do
    base = Time.utc(2026, 7, 10, 12)
    create_heartbeat(project: "served", language: "Ruby", time: base.to_f)
    create_heartbeat(project: "served", language: "Ruby", time: (base + 60.seconds).to_f)
    serving_queries = []
    subscriber = ActiveSupport::Notifications.subscribe("sql.clickhouse_serving") do |*, payload|
      serving_queries << payload.fetch(:sql)
    end

    summary = WakatimeService.new(
      user: @user,
      specific_filters: [ :languages ],
      allow_cache: false,
      limit: nil,
      start_date: base.beginning_of_day,
      end_date: base.end_of_day
    ).generate_summary

    assert_equal 60, summary[:total_seconds]
    assert_equal 1, serving_queries.size
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
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
    create_heartbeat_for(@user, project: project, language: language, time: time)
  end

  def create_heartbeat_for(user, project:, language:, time:)
    Clickhouse::HeartbeatWriter.create!(
      user_id: user.id,
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
