class My::StruggleController < InertiaController
  PREVIEW_WINDOWS_PER_PROJECT = 50
  MAX_EXPORT_WINDOWS = 10_000
  MAX_EXPORT_POINT_EVENTS = 10_000

  layout "inertia", only: [ :show ]

  before_action :ensure_current_user

  # GET /my/struggle
  def show
    unconverted_scope = current_user.struggle_windows.unconverted
    converted_scope = current_user.struggle_windows.converted
    is_admin = admin_viewer?

    unconverted_count, unconverted_sp, unconverted_raw, unconverted_convertible = unconverted_scope.pick(
      Arel.sql("COUNT(*)"),
      Arel.sql("COALESCE(SUM(struggle_points), 0)"),
      Arel.sql("COALESCE(SUM(raw_seconds), 0)"),
      Arel.sql("COALESCE(SUM(convertible_seconds), 0)")
    )

    total_converted_seconds = converted_scope.sum(:credited_seconds).to_i
    total_converted_windows = converted_scope.count
    avg_mult = converted_scope.average(:effective_multiplier).to_f

    project_aggregates = unconverted_scope
      .group(:project_hash)
      .select(
        "project_hash",
        "COUNT(*) AS windows_count",
        "COALESCE(SUM(struggle_points), 0) AS total_sp",
        "COALESCE(SUM(raw_seconds), 0) AS total_raw_seconds",
        "COALESCE(SUM(convertible_seconds), 0) AS convertible_seconds",
        "COALESCE(AVG(effective_multiplier), 0) AS avg_multiplier",
        "MAX(project_name) FILTER (WHERE project_name IS NOT NULL AND project_name <> '') AS project_name",
        "MAX(primary_language) FILTER (WHERE primary_language IS NOT NULL AND primary_language <> '') AS primary_language"
      )
      .order(Arel.sql("COALESCE(SUM(convertible_seconds), 0) DESC"))
      .to_a

    preview_by_project = fetch_preview_windows_by_project(unconverted_scope)

    project_groups = project_aggregates.map do |row|
      proj_hash = row.project_hash
      preview_windows = preview_by_project[proj_hash] || []
      total_count = row.windows_count.to_i
      {
        project_hash: proj_hash,
        project_name: row.project_name.presence || "project-#{proj_hash.first(8)}",
        primary_language: row.primary_language.presence || "Unknown",
        windows_count: total_count,
        total_sp: row.total_sp.to_f.round(2),
        total_raw_seconds: row.total_raw_seconds.to_i,
        convertible_seconds: row.convertible_seconds.to_i,
        avg_multiplier: row.avg_multiplier.to_f.round(3),
        has_more_windows: total_count > preview_windows.size,
        windows: preview_windows.map { |w| serialize_window(w) }
      }
    end

    conversions = current_user.struggle_conversions.order(converted_at: :desc).limit(25).map do |c|
      {
        id: c.id,
        project_name: c.project_name.presence || "All Projects",
        windows_count: c.windows_count,
        total_sp_converted: c.total_sp_converted.to_f.round(2),
        total_raw_seconds: c.total_raw_seconds,
        total_credited_seconds: c.total_credited_seconds,
        converted_at: c.converted_at.iso8601
      }
    end

    badge_handle = current_user.username.presence || current_user.id.to_s
    badge_url = "#{request.base_url}/api/v1/struggle_badge/#{badge_handle}.svg"

    user_events = current_user.struggle_point_events
    sp_breakdown = build_sp_breakdown(user_events, include_integrity: is_admin)
    recent_point_events = is_admin ? serialize_point_events(user_events.order(window_start: :desc, id: :desc).limit(60)) : []

    render inertia: "Struggle/Index", props: {
      page_title: "Struggle SP Converter | Hackatime",
      conversion_mode: "per_window_exact_cap",
      can_view_integrity_details: is_admin,
      summary: {
        unconverted_windows_count: unconverted_count.to_i,
        unconverted_sp: unconverted_sp.to_f.round(2),
        unconverted_raw_seconds: unconverted_raw.to_i,
        convertible_seconds: unconverted_convertible.to_i,
        total_converted_seconds: total_converted_seconds,
        total_converted_windows: total_converted_windows,
        avg_multiplier: avg_mult.round(3),
        badge_url: badge_url,
        badge_markdown: "![Hackatime AI Struggle Card](#{badge_url})"
      },
      project_groups: project_groups,
      sp_breakdown: sp_breakdown,
      recent_point_events: recent_point_events,
      conversions: conversions
    }
  end

  # GET /my/struggle/export
  def export
    is_admin = admin_viewer?
    windows_scope = current_user.struggle_windows
    total_windows = windows_scope.count
    exported_windows = windows_scope.order(window_start: :desc, id: :desc).limit(MAX_EXPORT_WINDOWS).map do |w|
      entry = {
        id: w.id,
        project_hash: w.project_hash,
        project_name: w.project_name.presence || "project-#{w.project_hash.first(8)}",
        window_start: w.window_start.iso8601,
        raw_seconds: w.raw_seconds,
        convertible_seconds: w.convertible_seconds,
        credited_seconds: w.credited_seconds,
        converted_at: w.converted_at&.iso8601,
        struggle_points: w.struggle_points.to_f.round(2),
        effective_multiplier: w.effective_multiplier.to_f.round(3),
        primary_language: w.primary_language,
        ai_harness: w.ai_harness,
        signal_counts: w.signal_counts || {},
        git_head_sha: w.git_head_sha,
        chain_hash: w.chain_hash
      }
      entry[:anomaly_flags] = w.anomaly_flags || [] if is_admin
      entry
    end

    conversions = current_user.struggle_conversions.order(converted_at: :desc, id: :desc).map do |c|
      {
        id: c.id,
        project_hash: c.project_hash,
        project_name: c.project_name.presence || "All Projects",
        windows_count: c.windows_count,
        total_sp_converted: c.total_sp_converted.to_f.round(2),
        total_raw_seconds: c.total_raw_seconds,
        total_credited_seconds: c.total_credited_seconds,
        converted_at: c.converted_at.iso8601
      }
    end

    payload = {
      exported_at: Time.current.iso8601,
      user: {
        id: current_user.id,
        username: current_user.username
      },
      summary: {
        total_windows: total_windows,
        exported_windows: exported_windows.size,
        truncated: total_windows > exported_windows.size,
        unconverted_windows: windows_scope.unconverted.count,
        converted_windows: windows_scope.converted.count,
        total_credited_seconds: windows_scope.converted.sum(:credited_seconds).to_i
      },
      sp_breakdown: build_sp_breakdown(current_user.struggle_point_events, include_integrity: is_admin),
      windows: exported_windows,
      conversions: conversions
    }
    if is_admin
      payload[:point_events] = serialize_point_events(
        current_user.struggle_point_events.order(window_start: :desc, id: :desc).limit(MAX_EXPORT_POINT_EVENTS)
      )
    end

    filename = "hackatime-struggle-export-#{Date.current.iso8601}.json"
    send_data JSON.pretty_generate(payload),
      filename: filename,
      type: "application/json; charset=utf-8",
      disposition: "attachment"
  end

  # POST /my/struggle/convert
  def convert
    result = StruggleConversionService.call(
      user: current_user,
      project_hash: params[:project_hash],
      window_ids: params[:window_ids]
    )

    if result.success?
      secs = result.conversion.total_credited_seconds.to_i
      dur = secs >= 3600 ? "#{secs / 3600}h #{(secs % 3600) / 60}m" : "#{secs / 60}m #{secs % 60}s"
      notice = if secs.positive?
        "Converted #{result.conversion.total_sp_converted.to_f.round(1)} SP (#{result.converted_count} windows) into #{dur} — credited to your Hackatime dashboard under Struggle Point Time!"
      else
        "Reconciled #{result.converted_count} windows (0m 0s added — those intervals were already covered by existing Hackatime heartbeats)."
      end
      redirect_to my_struggle_path, notice: notice
    else
      redirect_to my_struggle_path, alert: result.error
    end
  end

  private

  def ensure_current_user
    redirect_to root_path, alert: "You must be logged in to view this page" unless current_user
  end

  def admin_viewer?
    current_user.admin_level.in?(%w[admin superadmin ultraadmin])
  end

  # Hide internal anti-cheat gate counts and raw pre-gate points from non-admins
  # so the page cannot be used as an oracle to tune automated farming scripts.
  def build_sp_breakdown(events_scope, include_integrity:)
    rows = StrugglePointEvent.signal_breakdown_summary(events_scope)
    return rows if include_integrity

    rows.filter_map do |row|
      next if row[:awarded_points].to_f <= 0

      {
        signal_code: row[:signal_code],
        label: row[:label],
        trigger_count: row[:trigger_count],
        awarded_points: row[:awarded_points],
        total_windows: row[:total_windows]
      }
    end
  end

  def serialize_point_events(events_scope)
    events_scope.map do |ev|
      {
        id: ev.id,
        window_start: ev.window_start.iso8601,
        project_name: ev.project_name.presence || "project-#{ev.project_hash.first(8)}",
        signal_code: ev.signal_code,
        signal_label: ev.signal_label,
        trigger_count: ev.trigger_count,
        raw_points: ev.raw_points.to_f.round(2),
        awarded_points: ev.awarded_points.to_f.round(2),
        provenance_tier: ev.provenance_tier,
        persisted_diff_lines: ev.persisted_diff_lines,
        git_head_sha: ev.git_head_sha&.first(8),
        gate_status: ev.gate_status,
        gate_label: ev.gate_label
      }
    end
  end

  def fetch_preview_windows_by_project(unconverted_scope)
    ranked = unconverted_scope.select(
      "struggle_windows.*",
      "ROW_NUMBER() OVER (PARTITION BY project_hash ORDER BY window_start DESC, id DESC) AS project_row_num"
    )
    StruggleWindow
      .from(ranked, :struggle_windows)
      .where("project_row_num <= ?", PREVIEW_WINDOWS_PER_PROJECT)
      .order(window_start: :desc, id: :desc)
      .to_a
      .group_by(&:project_hash)
  end

  def serialize_window(w)
    {
      id: w.id,
      window_start: w.window_start.iso8601,
      raw_seconds: w.raw_seconds,
      convertible_seconds: w.convertible_seconds,
      struggle_points: w.struggle_points.to_f.round(2),
      effective_multiplier: w.effective_multiplier.to_f.round(3),
      verify_multiplier: w.verify_multiplier.to_f.round(2),
      provenance_mask: w.provenance_mask,
      ai_harness: w.ai_harness,
      signal_counts: w.signal_counts || {},
      git_head_sha: w.git_head_sha&.first(8)
    }
  end
end
