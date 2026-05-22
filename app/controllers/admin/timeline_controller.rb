class Admin::TimelineController < Admin::BaseController
  include ApplicationHelper

  USER_SELECT_FIELDS = %i[id username slack_username github_username slack_avatar_url github_avatar_url].freeze

  def show
    @date ||= params[:date] ? Date.parse(params[:date]) : Time.current.to_date
    @next_date = @date + 1.day
    @prev_date = @date - 1.day

    raw_user_ids = params[:user_ids].present? ? params[:user_ids].split(",").map(&:to_i).uniq : []
    raw_user_ids += User.where(slack_uid: params[:slack_uids].split(",")).pluck(:id) if params[:slack_uids].present?

    @selected_user_ids = ([ current_user.id ] + raw_user_ids).uniq

    service = TimelineService.new(date: @date, selected_user_ids: @selected_user_ids)
    timeline_data_unordered = service.timeline_data

    data_map = timeline_data_unordered.index_by { |data| data[:user].id }
    @users_with_timeline_data = @selected_user_ids.map do |id|
      data_map[id] || (service.users_by_id[id] ? { user: service.users_by_id[id], spans: [], total_coded_time: 0 } : nil)
    end.compact

    @initial_selected_user_objects = User.where(id: @selected_user_ids)
                                         .select(*USER_SELECT_FIELDS)
                                         .map { |u| user_summary(u) }
                                         .sort_by { |u| @selected_user_ids.index(u[:id]) || Float::INFINITY }

    @primary_user = @users_with_timeline_data.first&.[](:user) || current_user
    @timeline_commit_markers = service.commit_markers

    render :show
  end

  def search_users
    query_term = params[:query].to_s.downcase

    if query_term.match?(/^\d+$/) && (match = User.find_by(id: query_term.to_i))
      return render json: [ user_summary(match) ]
    end

    users = User.where(
      "LOWER(username) LIKE :query OR LOWER(slack_username) LIKE :query OR CAST(id AS TEXT) LIKE :query OR EXISTS (SELECT 1 FROM email_addresses WHERE email_addresses.user_id = users.id AND LOWER(email_addresses.email) LIKE :query)",
      query: "%#{query_term}%"
    ).order(Arel.sql("CASE WHEN LOWER(username) = #{ActiveRecord::Base.connection.quote(query_term)} THEN 0 ELSE 1 END, username ASC"))
     .limit(20).select(*USER_SELECT_FIELDS)

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

    users_data = User.where(id: all_ids_to_fetch).select(*USER_SELECT_FIELDS).index_by(&:id)

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

  def user_summary(user) = { id: user.id, display_name: user.display_name.to_s, avatar_url: user.avatar_url }
end
