class Admin::TimelineController < Admin::BaseController
  include ApplicationHelper

  def show
    @date ||= params[:date] ? Date.parse(params[:date]) : Time.current.to_date
    @next_date = @date + 1.day
    @prev_date = @date - 1.day

    raw_user_ids = params[:user_ids].present? ? params[:user_ids].split(",").map(&:to_i).uniq : []

    if params[:slack_uids].present?
      slack_uids = params[:slack_uids].split(",")
      users_from_slack_uids = User.where(slack_uid: slack_uids)
      raw_user_ids += users_from_slack_uids.pluck(:id)
    end

    @selected_user_ids = [ current_user.id ] + raw_user_ids
    @selected_user_ids.uniq!

    service = TimelineService.new(date: @date, selected_user_ids: @selected_user_ids)
    timeline_data_unordered = service.timeline_data

    data_map = timeline_data_unordered.index_by { |data| data[:user].id }
    @users_with_timeline_data = @selected_user_ids.map do |id|
      data_map[id] || (service.users_by_id[id] ? { user: service.users_by_id[id], spans: [], total_coded_time: 0 } : nil)
    end.compact

    @initial_selected_user_objects = User.where(id: @selected_user_ids)
                                        .select(:id, :username, :slack_username, :github_username, :slack_avatar_url, :github_avatar_url)
                                        .map { |u| { id: u.id, display_name: "#{u.display_name}", avatar_url: u.avatar_url } }
                                        .sort_by { |u_obj| @selected_user_ids.index(u_obj[:id]) || Float::INFINITY }

    @primary_user = @users_with_timeline_data.first&.[](:user) || current_user
    @timeline_commit_markers = service.commit_markers

    render :show
  end

  def search_users
    query_term = params[:query].to_s.downcase

    user_id_match = nil
    if query_term.match?(/^\d+$/)
      user_id = query_term.to_i
      user_id_match = User.where(id: user_id).first
    end

    if user_id_match
      results = [ {
        id: user_id_match.id,
        display_name: "#{user_id_match.display_name}",
        avatar_url: user_id_match.avatar_url
      } ]
    else
      users = User.where("LOWER(username) LIKE :query OR LOWER(slack_username) LIKE :query OR CAST(id AS TEXT) LIKE :query OR EXISTS (SELECT 1 FROM email_addresses WHERE email_addresses.user_id = users.id AND LOWER(email_addresses.email) LIKE :query)", query: "%#{query_term}%")
                  .order(Arel.sql("CASE WHEN LOWER(username) = #{ActiveRecord::Base.connection.quote(query_term)} THEN 0 ELSE 1 END, username ASC"))
                  .limit(20)
                  .select(:id, :username, :slack_username, :github_username, :slack_avatar_url, :github_avatar_url)

      results = users.map do |user|
        {
          id: user.id,
          display_name: "#{user.display_name}",
          avatar_url: user.avatar_url
        }
      end
    end

    render json: results
  end

  def leaderboard_users
    period = params[:period]
    limit = 25

    leaderboard_period_type = (period == "last_7_days") ? :last_7_days : :daily
    start_date = Date.current

    leaderboard = Leaderboard.where.not(finished_generating_at: nil)
                             .find_by(start_date: start_date, period_type: leaderboard_period_type, deleted_at: nil)

    user_ids_from_leaderboard = leaderboard ? leaderboard.entries.order(total_seconds: :desc).limit(limit).pluck(:user_id) : []

    all_ids_to_fetch = user_ids_from_leaderboard.dup
    all_ids_to_fetch.unshift(current_user.id).uniq!

    users_data = User.where(id: all_ids_to_fetch)
                     .select(:id, :username, :slack_username, :github_username, :slack_avatar_url, :github_avatar_url)
                     .index_by(&:id)

    final_user_objects = []
    if admin_data = users_data[current_user.id]
      final_user_objects << { id: admin_data.id, display_name: "#{admin_data.display_name}", avatar_url: admin_data.avatar_url }
    end

    user_ids_from_leaderboard.each do |uid|
      break if final_user_objects.size >= limit
      next if uid == current_user.id

      if user_data = users_data[uid]
        final_user_objects << { id: user_data.id, display_name: "#{user_data.display_name}", avatar_url: user_data.avatar_url }
      end
    end

    render json: { users: final_user_objects }
  end
end
