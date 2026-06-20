class ProjectStatsService
  def initialize(heartbeats)
    @hb = heartbeats
  end

  def call
    {
      total_time: total_time,
      file_count: file_count,
      language_stats: language_stats,
      language_colors: language_colors,
      editor_stats: editor_stats,
      os_stats: os_stats,
      category_stats: category_stats,
      file_stats: file_stats,
      branch_stats: branch_stats
    }
  end

  private

  attr_reader :hb

  def h = ApplicationController.helpers

  def total_time = @total_time ||= hb.duration_seconds

  def file_count = hb.select(:entity).distinct.count

  def grouped(field, n, normalize: ->(k) { k.to_s }, display: nil)
    result = Heartbeat.attributed_durations_by(hb, field).each_with_object({}) do |(raw, dur), agg|
      k = normalize.call(raw)
      agg[k] = (agg[k] || 0) + dur
    end.sort_by { |_, d| -d }.first(n)
    display ? result.map { |k, v| [ display.call(k), v ] }.to_h : result.to_h
  end

  def language_stats
    @language_stats ||= grouped(:language, 15, normalize: ->(k) { k.to_s.categorize_language })
  end

  def language_colors = language_stats.present? ? LanguageUtils.colors_for(language_stats.keys) : {}

  def editor_stats
    grouped(:editor, 10, normalize: ->(k) { k.to_s.downcase }, display: ->(k) { h.display_editor_name(k) })
  end

  def os_stats
    grouped(:operating_system, 10, normalize: ->(k) { k.to_s.downcase }, display: ->(k) { h.display_os_name(k) })
  end

  def category_stats = grouped(:category, 10)

  def file_stats
    Heartbeat.attributed_durations_by(hb, :entity)
      .reject { |_, dur| dur < 60 }
      .sort_by { |_, d| -d }.first(50)
      .map { |entity, dur| [ h.shorten_file_path(entity), dur ] }
  end

  def branch_stats = Heartbeat.attributed_durations_by(hb, :branch).sort_by { |_, d| -d }.first(10)
end
