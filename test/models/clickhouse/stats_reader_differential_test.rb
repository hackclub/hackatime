require "test_helper"

class Clickhouse::StatsReaderDifferentialTest < ActiveSupport::TestCase
  DIMENSION_FILTERS = {
    language: %w[Ruby Python TypeScript],
    editor: %w[vscode neovim],
    category: %w[coding debugging]
  }.freeze
  PROJECTS = %w[alpha beta gamma].freeze

  test "serving readers retain raw query semantics through canonical changes" do
    user = User.create!(timezone: "UTC")
    rows = Clickhouse::HeartbeatWriter.insert_rows(initial_rows(user), maintain_serving_tables: false)
    HeartbeatIntervals::UserRebuilder.call(user_id: user.id, reason: "differential_seed")

    assert_reader_parity(user)

    appended_rows = [ 174_060, 174_120, 174_180 ].each_with_index.map do |offset, sequence|
      heartbeat_attributes(user, time: (Time.utc(2026, 7, 7, 23, 58) + offset.seconds).to_f, sequence: sequence + 100)
    end
    Clickhouse::HeartbeatWriter.insert_rows(appended_rows)
    assert_reader_parity(user)

    Clickhouse::HeartbeatWriter.insert_rows([ rows.fetch(8) ])
    assert_reader_parity(user)

    late_row = heartbeat_attributes(user, time: Time.utc(2026, 7, 8, 0, 1, 15).to_f, sequence: 99)
    Clickhouse::HeartbeatWriter.insert_rows([ late_row ])
    assert_reader_parity(user)

    heartbeat = Clickhouse::Heartbeat.instantiate(
      rows.fetch(17).transform_values { |value| value.is_a?(Symbol) ? value.to_s : value }
    )
    soft_delete_heartbeat(heartbeat)
    assert_reader_parity(user)

    restore_heartbeat(heartbeat)
    assert_reader_parity(user)
  end

  test "rebuild preserves nil and blank projects as distinct duration buckets" do
    user = User.create!(timezone: "UTC")
    base = Time.utc(2026, 7, 14, 12)
    projects = [ nil, "", nil, "", "named", "named" ]
    offsets = [ 0, 30, 60, 90, 120, 180 ]
    rows = projects.zip(offsets).each_with_index.map do |(project, offset), sequence|
      heartbeat_attributes(user, time: (base + offset.seconds).to_f, sequence: sequence).merge(project: project)
    end

    Clickhouse::HeartbeatWriter.insert_rows(rows, maintain_serving_tables: false)
    HeartbeatIntervals::UserRebuilder.call(user_id: user.id, reason: "nil_blank_project_differential")

    raw = Clickhouse::Heartbeat.for_user(user).group(:project).duration_seconds
    assert_equal({ nil => 60, "" => 60, "named" => 60 }, raw)
    assert_equal raw, Clickhouse::StatsReader.new(user).project_durations
  end

  private

  def initial_rows(user)
    base = Time.utc(2026, 7, 7, 23, 58)
    offsets = [
      0, 20, 65, 130, 260, 300, 420, 700, 760, 900,
      86_390, 86_430, 86_500, 86_620, 86_900, 87_030, 87_400,
      172_790, 172_830, 172_900, 173_050, 173_400, 173_460, 174_000
    ]
    offsets.each_with_index.map do |offset, sequence|
      heartbeat_attributes(user, time: (base + offset.seconds).to_f, sequence: sequence)
    end.reverse
  end

  def heartbeat_attributes(user, time:, sequence:)
    {
      user_id: user.id,
      time: time,
      project: sequence % 7 == 0 ? "" : PROJECTS.fetch(sequence % PROJECTS.length),
      language: DIMENSION_FILTERS.fetch(:language).fetch(sequence % 3),
      editor: DIMENSION_FILTERS.fetch(:editor).fetch(sequence % 2),
      operating_system: sequence.even? ? "macOS" : "Linux",
      machine: sequence.even? ? "laptop" : "desktop",
      category: DIMENSION_FILTERS.fetch(:category).fetch(sequence % 2),
      entity: "app/file_#{sequence % 5}.rb",
      branch: sequence.even? ? "main" : "feature",
      source_type: :test_entry
    }
  end

  def assert_reader_parity(user)
    reader = Clickhouse::StatsReader.new(user)
    raw = Clickhouse::Heartbeat.for_user(user)

    assert_equal raw.duration_seconds, reader.total_seconds
    assert_equal positive(raw.group(:project).duration_seconds), positive(reader.project_durations)

    ranges.each do |start_time, end_time|
      range_scope = raw.where("time >= ? AND time < ?", start_time.to_f, end_time.to_f)
      range = { start_time: start_time, end_time: end_time }

      assert_equal range_scope.duration_seconds, reader.total_seconds(**range)
      assert_equal positive(range_scope.group(:project).duration_seconds),
        positive(reader.project_durations(**range))
      assert_equal range_scope.distinct.count(Arel.sql("toDate(toDateTime64(time, 3, 'UTC'))")),
        reader.days_with_heartbeats(**range)

      DIMENSION_FILTERS.each do |dimension, values|
        values.each do |value|
          assert_equal range_scope.where(dimension => value).duration_seconds,
            reader.total_seconds(**range, filters: { dimension => value })
        end
        assert_equal Clickhouse::Heartbeat.attributed_durations_by(range_scope, dimension),
          reader.dimension_durations(**range, dimension: dimension)
        assert_equal range_scope.group(dimension).duration_seconds,
          reader.filter_durations(**range, dimension: dimension)
      end

      PROJECTS.each do |project|
        project_scope = range_scope.where(project: project)
        assert_equal project_scope.duration_seconds,
          reader.total_seconds(**range, filters: { project: project })
        DIMENSION_FILTERS.each_key do |dimension|
          assert_equal Clickhouse::Heartbeat.attributed_durations_by(project_scope, dimension),
            reader.project_dimension_durations(**range, project: project, dimension: dimension)
        end
      end
    end
  end

  def ranges
    [
      [ Time.utc(2026, 7, 7), Time.utc(2026, 7, 11) ],
      [ Time.utc(2026, 7, 8), Time.utc(2026, 7, 9) ],
      [ Time.utc(2026, 7, 9), Time.utc(2026, 7, 11) ]
    ]
  end

  def positive(durations)
    durations.each_with_object({}) do |(key, seconds), result|
      result[key] = seconds if seconds.positive?
    end
  end
end
