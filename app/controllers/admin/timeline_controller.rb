class Admin::TimelineController < Admin::BaseController
  include ApplicationHelper

  def show
    @date = parse_date_param
    service = TimelineService.for_selection(
      date: @date,
      current_user: current_user,
      user_ids: params[:user_ids],
      slack_uids: params[:slack_uids]
    )
    @users_with_timeline_data = service.timeline_data

    @primary_user = @users_with_timeline_data.first&.[](:user) || current_user
    primary_timezone = @primary_user.timezone.presence || current_user.timezone.presence || "UTC"

    render inertia: "Admin/Timeline", props: {
      current_user: user_summary(current_user).merge(admin_level: current_user.admin_level),
      selected_users: service.users.map { |user| user_summary(user) },
      date: @date.to_s,
      date_label: @date.in_time_zone(primary_timezone).strftime("%A, %B %-d, %Y"),
      today: Time.current.to_date.to_s,
      columns: timeline_columns(primary_timezone),
      commits: service.commit_markers
    }
  end

  def search_users
    return render json: [] if params[:query].blank?

    users = TimelineService.search_users(params[:query])
    render json: users.map { |u| user_summary(u) }
  end

  def leaderboard_users
    users = TimelineService.leaderboard_users(current_user: current_user, period: params[:period])
    render json: { users: users.map { |user| user_summary(user) } }
  end

  private

  def parse_date_param
    params[:date].present? ? Date.parse(params[:date].to_s) : Time.current.to_date
  rescue Date::Error
    Time.current.to_date
  end

  def inertia_layout_props = super.merge(full_width: true, hide_footer: true, viewport_fit: true)

  def user_summary(user) = { id: user.id, display_name: user.display_name.to_s, avatar_url: user.avatar_url }

  def timeline_columns(primary_timezone)
    @users_with_timeline_data.map do |data|
      user = data[:user]
      timezone = user.timezone.presence || primary_timezone
      {
        user: {
          id: user.id, display_name: user.display_name.to_s, avatar_url: user.avatar_url,
          timezone: timezone, slack_url: user == current_user || user.slack_uid.blank? ? nil : "slack://user?team=T0266FRGM&id=#{user.slack_uid}",
          github_url: user.github_profile_url, trust_level: user.trust_level,
          can_impersonate: current_user.can_impersonate?(user)
        },
        total: data[:total_coded_time].to_i,
        total_short: short_time_simple(data[:total_coded_time]),
        total_detailed: short_time_detailed(data[:total_coded_time]),
        day_start_epoch: @date.in_time_zone(timezone).beginning_of_day.to_i,
        spans: Array(data[:spans]).map { |span| span_props(span, timezone) }
      }
    end
  end

  def span_props(span, timezone)
    start_time = Time.at(span[:start_time]).in_time_zone(timezone)
    end_time = Time.at(span[:end_time] || span[:start_time] + span[:duration]).in_time_zone(timezone)
    projects = span[:projects_edited_details] || []
    title = []
    title << "Languages: #{span[:languages].join(', ')}" if span[:languages]&.any?
    title << "Projects: #{projects.map { |p| "#{p[:name]}#{p[:repo_url] ? ' (GitHub)' : ' (No Repo)'}" }.join('; ')}" if projects.any?
    title << "Editors: #{span[:editors].join(', ')}" if span[:editors]&.any?
    files = span[:files_edited] || []
    title << "Files: #{files.take(5).join(', ')}#{", +#{files.length - 5} more" if files.length > 5}" if files.any?
    title << "Duration: #{Time.at(span[:duration]).utc.strftime('%Hh %Mm %Ss')}"
    title << "Time: #{start_time.strftime('%-l:%M %p')} - #{end_time.strftime('%-l:%M %p')}"
    {
      start_epoch: span[:start_time].to_f, end_epoch: (span[:end_time] || span[:start_time] + span[:duration]).to_f,
      title: title.join("\n"), projects: projects, languages: span[:languages]&.any? ? span[:languages].join(", ") : "-",
      time: "#{start_time.strftime('%-l:%M %p')} - #{end_time.strftime('%-l:%M %p')}"
    }
  end
end
