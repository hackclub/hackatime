class ProjectStatsService
  FIELDS = %i[
    total_time file_count language_stats language_colors
    editor_stats os_stats category_stats file_stats branch_stats
  ].freeze

  # The heartbeat column each stat is attributed by; all are read in one query.
  ATTRIBUTED_COLUMNS = {
    file_count: :entity, language_stats: :language, language_colors: :language, editor_stats: :editor,
    os_stats: :operating_system, category_stats: :category, file_stats: :entity, branch_stats: :branch
  }.freeze

  def initialize(heartbeats)
    @hb = heartbeats
  end

  def call(only: FIELDS)
    @columns = ATTRIBUTED_COLUMNS.values_at(*only).compact.uniq
    only.index_with { |key| send(key) }
  end

  private

  attr_reader :hb

  def h = ApplicationController.helpers

  def attribution = @attribution ||= Heartbeat.attributed_durations_by_fields(hb, @columns)
  def attributed(column) = attribution.last.fetch(column).reject { |bucket, _| bucket.blank? }

  def total_time = attribution.first

  def file_count = attribution.last.fetch(:entity).keys.compact.size

  def grouped(field, n, normalize: ->(k) { k.to_s }, display: nil)
    result = attributed(field).each_with_object({}) do |(raw, dur), agg|
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
    attributed(:entity)
      .reject { |_, dur| dur < 60 }
      .sort_by { |_, d| -d }.first(50)
      .map { |entity, dur| [ h.shorten_file_path(entity), dur ] }
  end

  def branch_stats = attributed(:branch).sort_by { |_, d| -d }.first(10)
end
