class My::StruggleController < InertiaController
  layout "inertia", only: [ :show ]

  before_action :ensure_current_user

  # GET /my/struggle
  def show
    unconverted = current_user.struggle_windows.unconverted.order(window_start: :desc).limit(500).to_a
    converted_scope = current_user.struggle_windows.converted

    total_converted_seconds = converted_scope.sum(:credited_seconds).to_i
    total_converted_windows = converted_scope.count
    avg_mult = converted_scope.average(:effective_multiplier).to_f

    project_groups = unconverted.group_by(&:project_hash).map do |proj_hash, windows|
      name = windows.find { |w| w.project_name.present? }&.project_name || "project-#{proj_hash.first(8)}"
      lang = windows.find { |w| w.primary_language.present? }&.primary_language || "Unknown"
      {
        project_hash: proj_hash,
        project_name: name,
        primary_language: lang,
        windows_count: windows.size,
        total_sp: windows.sum { |w| w.struggle_points.to_f }.round(2),
        total_raw_seconds: windows.sum(&:raw_seconds),
        convertible_seconds: windows.sum(&:convertible_seconds),
        avg_multiplier: (windows.sum { |w| w.effective_multiplier.to_f } / windows.size).round(3),
        windows: windows.map { |w| serialize_window(w) }
      }
    end.sort_by { |g| -g[:convertible_seconds] }

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

    render inertia: "Struggle/Index", props: {
      page_title: "Struggle SP Converter | Hackatime",
      conversion_mode: "per_window_exact_cap",
      summary: {
        unconverted_windows_count: unconverted.size,
        unconverted_sp: unconverted.sum { |w| w.struggle_points.to_f }.round(2),
        unconverted_raw_seconds: unconverted.sum(&:raw_seconds),
        convertible_seconds: unconverted.sum(&:convertible_seconds),
        total_converted_seconds: total_converted_seconds,
        total_converted_windows: total_converted_windows,
        avg_multiplier: avg_mult.round(3),
        badge_url: badge_url,
        badge_markdown: "![Hackatime AI Struggle Card](#{badge_url})"
      },
      project_groups: project_groups,
      conversions: conversions
    }
  end

  # POST /my/struggle/convert
  def convert
    result = StruggleConversionService.call(
      user: current_user,
      project_hash: params[:project_hash],
      window_ids: params[:window_ids]
    )

    if result.success?
      hours = (result.conversion.total_credited_seconds / 3600.0).round(2)
      redirect_to my_struggle_path,
        notice: "Converted #{result.conversion.total_sp_converted.to_f.round(1)} SP (#{result.converted_count} windows) into #{hours}h of verified Struggle Hours!"
    else
      redirect_to my_struggle_path, alert: result.error
    end
  end

  private

  def ensure_current_user
    redirect_to root_path, alert: "You must be logged in to view this page" unless current_user
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
