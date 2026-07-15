class ProjectStatsServingService
  FIELDS = ProjectStatsService::FIELDS
  FIELD_DIMENSIONS = {
    file_count: :entity,
    language_stats: :language,
    language_colors: :language,
    editor_stats: :editor,
    os_stats: :operating_system,
    category_stats: :category,
    file_stats: :entity,
    branch_stats: :branch
  }.freeze

  def initialize(user:, project:, start_time: nil, end_time: nil)
    @user = user
    @project = project
    @start_time = start_time
    @end_time = end_time
    @reader = Clickhouse::StatsReader.new(user)
  end

  def call(only: FIELDS)
    dimensions = only.filter_map { |field| FIELD_DIMENSIONS[field] }.uniq
    @project_stats = reader.project_stats(
      project:, dimensions:, include_total: only.include?(:total_time), start_time:, end_time:
    )
    only.index_with { |key| send(key) }
  end

  private

  attr_reader :user, :project, :start_time, :end_time, :reader

  def h = ApplicationController.helpers

  def total_time
    project_stats.fetch(:total_seconds)
  end

  def file_count
    dimension_rows(:entity).count { |_, values| values.fetch(:heartbeat_count).positive? }
  end

  def grouped(field, n, normalize: ->(k) { k.to_s }, display: nil)
    dimension_durations(field)
      .each_with_object({}) do |(raw, dur), agg|
        key = normalize.call(raw)
        next if key.blank?

        agg[key] = (agg[key] || 0) + dur
      end
      .sort_by { |key, duration| [ -duration, key.to_s ] }
      .first(n)
      .then { |result| display ? result.map { |key, value| [ display.call(key), value ] }.to_h : result.to_h }
  end

  def language_stats
    @language_stats ||= grouped(:language, 15, normalize: ->(key) { key.to_s.categorize_language })
  end

  def language_colors = language_stats.present? ? LanguageUtils.colors_for(language_stats.keys) : {}

  def editor_stats
    grouped(:editor, 10, normalize: ->(key) { key.to_s.downcase }, display: ->(key) { h.display_editor_name(key) })
  end

  def os_stats
    grouped(:operating_system, 10, normalize: ->(key) { key.to_s.downcase }, display: ->(key) { h.display_os_name(key) })
  end

  def category_stats = grouped(:category, 10)

  def file_stats
    dimension_durations(:entity)
      .reject { |entity, duration| entity.blank? || duration < 60 }
      .sort_by { |entity, duration| [ -duration, entity.to_s ] }
      .first(50)
      .map { |entity, duration| [ h.shorten_file_path(entity), duration ] }
  end

  def branch_stats
    dimension_durations(:branch)
      .sort_by { |branch, duration| [ -duration, branch.to_s ] }
      .first(10)
  end

  def project_stats
    @project_stats || raise("project stats must be loaded through #call")
  end

  def dimension_rows(dimension)
    project_stats.fetch(:dimensions).fetch(dimension, {})
  end

  def dimension_durations(dimension)
    dimension_rows(dimension).transform_values { |values| values.fetch(:seconds) }
  end
end
