class Admin::TimelineController < Admin::BaseController
  include ApplicationHelper

  USER_SELECT_FIELDS = %i[id username slack_username github_username slack_avatar_url github_avatar_url display_name_override].freeze

  def show
    @date = parse_date_param
    raw_user_ids = params[:user_ids].present? ? params[:user_ids].split(",").map(&:to_i).uniq : []
    raw_user_ids += User.where(slack_uid: params[:slack_uids].split(",")).pluck(:id) if params[:slack_uids].present?

    @selected_user_ids = ([ current_user.id ] + raw_user_ids).uniq

    service = TimelineService.new(date: @date, selected_user_ids: @selected_user_ids)
    timeline_data_unordered = service.timeline_data

    data_map = timeline_data_unordered.index_by { |data| data[:user].id }
    @users_with_timeline_data = @selected_user_ids.map do |id|
      data_map[id] || (service.users_by_id[id] ? { user: service.users_by_id[id], spans: [], total_coded_time: 0 } : nil)
    end.compact

    selected_users = User.where(id: @selected_user_ids).select(*USER_SELECT_FIELDS).preload(:email_addresses)
                         .map { |u| user_summary(u) }
                         .sort_by { |u| @selected_user_ids.index(u[:id]) || Float::INFINITY }

    @primary_user = @users_with_timeline_data.first&.[](:user) || current_user
    primary_timezone = @primary_user.timezone.presence || current_user.timezone.presence || "UTC"

    render inertia: "Admin/Timeline", props: {
      current_user: user_summary(current_user).merge(admin_level: current_user.admin_level),
      selected_users: selected_users,
      date: @date.to_s,
      date_label: @date.in_time_zone(primary_timezone).strftime("%A, %B %-d, %Y"),
      today: Time.current.to_date.to_s,
      columns: timeline_columns(primary_timezone),
      commits: service.commit_markers
    }
  end

  def search_users
    return render json: [] if params[:query].blank?

    users = User.fuzzy_ranked_search(params[:query], limit: 20)
    render json: users.map { |u| user_summary(u) }
  end

  def leaderboard_users
    limit = 25
    leaderboard = Leaderboard.where.not(finished_generating_at: nil)
                             .find_by(start_date: Date.current,
                                      period_type: (params[:period] == "last_7_days") ? :last_7_days : :daily,
                                      deleted_at: nil)

    user_ids_from_leaderboard = leaderboard ? leaderboard.entries.order(total_seconds: :desc).limit(limit).pluck(:user_id) : []
    all_ids_to_fetch = ([ current_user.id ] + user_ids_from_leaderboard).uniq

    users_data = User.where(id: all_ids_to_fetch).select(*USER_SELECT_FIELDS).preload(:email_addresses).index_by(&:id)

    final_user_objects = []
    final_user_objects << user_summary(users_data[current_user.id]) if users_data[current_user.id]

    user_ids_from_leaderboard.each do |uid|
      break if final_user_objects.size >= limit
      next if uid == current_user.id
      final_user_objects << user_summary(users_data[uid]) if users_data[uid]
    end

    render json: { users: final_user_objects }
  end

  private

  def parse_date_param
    params[:date].present? ? Date.parse(params[:date].to_s) : Time.current.to_date
  rescue Date::Error
    Time.current.to_date
  end

  def inertia_layout_props = super.merge(full_width: true)

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
