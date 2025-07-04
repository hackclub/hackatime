class Admin::TimelineController < Admin::BaseController
  include ApplicationHelper # For short_time_simple, short_time_detailed helpers

  def show
    # for span calculations (visual blocks in the timeline)
    timeout_duration = 10.minutes.to_i # This remains for span display

    # Determine the date to display (default to today)
    @date ||= params[:date] ? Date.parse(params[:date]) : Time.current.to_date

    # Calculate next and previous dates
    @next_date = @date + 1.day
    @prev_date = @date - 1.day

    # User selection logic
    raw_user_ids = params[:user_ids].present? ? params[:user_ids].split(",").map(&:to_i).uniq : []

    # Handle slack_uids parameter
    if params[:slack_uids].present?
      slack_uids = params[:slack_uids].split(",")
      users_from_slack_uids = User.where(slack_uid: slack_uids)
      raw_user_ids += users_from_slack_uids.pluck(:id)
    end

    # Always include current_user (admin)
    @selected_user_ids = [ current_user.id ] + raw_user_ids
    @selected_user_ids.uniq!

    user_ids_to_fetch = @selected_user_ids

    # Fetch all valid users in one go
    users_by_id = User.where(id: user_ids_to_fetch).index_by(&:id)
    # Ensure we only use IDs of users that actually exist
    valid_user_ids_to_fetch = users_by_id.keys

    mappings_by_user_project = ProjectRepoMapping.where(user_id: valid_user_ids_to_fetch)
                                                 .group_by(&:user_id)
                                                 .transform_values { |mappings| mappings.index_by(&:project_name) }

    users_to_process = valid_user_ids_to_fetch.map { |id| users_by_id[id] }.compact

    # Get all heartbeats for all users within a broader time range (to account for timezone differences)
    # We'll filter by user timezone later for accuracy
    server_start_of_day = @date.beginning_of_day.to_f
    server_end_of_day = @date.end_of_day.to_f
    # Expand range by 24 hours on each side to account for timezone differences
    expanded_start = server_start_of_day - 24.hours.to_i
    expanded_end = server_end_of_day + 24.hours.to_i

    all_heartbeats = Heartbeat
                      .where(user_id: valid_user_ids_to_fetch, deleted_at: nil)
                      .where("time >= ? AND time <= ?", expanded_start, expanded_end)
                      .select(:id, :user_id, :time, :entity, :project, :editor, :language)
                      .order(:user_id, :time)
                      .to_a

    heartbeats_by_user_id = all_heartbeats.group_by(&:user_id)

    @users_with_timeline_data_unordered = []

    users_to_process.each do |user|
      # Calculate day boundaries in user's timezone
      user_tz = user.timezone || "UTC"
      user_start_of_day = @date.in_time_zone(user_tz).beginning_of_day.to_f
      user_end_of_day = @date.in_time_zone(user_tz).end_of_day.to_f

      user_daily_heartbeats_relation = Heartbeat.where(user_id: user.id, deleted_at: nil)
                                                .where("time >= ? AND time <= ?", user_start_of_day, user_end_of_day)
      total_coded_time_seconds = user_daily_heartbeats_relation.duration_seconds

      # Filter heartbeats for spans by user's timezone day boundaries
      all_user_heartbeats = heartbeats_by_user_id[user.id] || []
      user_heartbeats_for_spans = all_user_heartbeats.select { |hb| hb.time >= user_start_of_day && hb.time <= user_end_of_day }
      calculated_spans_with_details = []

      if user_heartbeats_for_spans.any?
        current_span_heartbeats = []
        user_heartbeats_for_spans.each_with_index do |heartbeat, index|
          current_span_heartbeats << heartbeat
          is_last_heartbeat = (index == user_heartbeats_for_spans.length - 1)
          time_to_next = is_last_heartbeat ? Float::INFINITY : (user_heartbeats_for_spans[index + 1].time - heartbeat.time)

          if time_to_next > timeout_duration || is_last_heartbeat
            if current_span_heartbeats.any?
              start_time_numeric = current_span_heartbeats.first.time
              last_hb_time_numeric = current_span_heartbeats.last.time
              span_duration = last_hb_time_numeric - start_time_numeric # This is span length, not necessarily active coding time within span
              span_duration = 0 if span_duration < 0

              files = current_span_heartbeats.map { |h| h.entity&.split("/")&.last }.compact.uniq
              projects_edited_details_for_span = []
              unique_project_names_in_current_span = current_span_heartbeats.map(&:project).compact.reject(&:blank?).uniq

              unique_project_names_in_current_span.each do |p_name|
                repo_mapping = mappings_by_user_project.dig(user.id, p_name)
                projects_edited_details_for_span << {
                  name: p_name,
                  repo_url: repo_mapping&.repo_url
                }
              end

              editors = current_span_heartbeats.map(&:editor).compact.uniq
              languages = current_span_heartbeats.map(&:language).compact.uniq

              calculated_spans_with_details << {
                start_time: start_time_numeric,
                end_time: last_hb_time_numeric, # Explicitly pass end_time of the span
                duration: span_duration, # Duration of the span itself
                files_edited: files,
                projects_edited_details: projects_edited_details_for_span,
                editors: editors,
                languages: languages
              }
              current_span_heartbeats = []
            end
          end
        end
      end

      # Add user data, even if no spans/time, if they were explicitly selected
      @users_with_timeline_data_unordered << {
        user: user,
        spans: calculated_spans_with_details,
        total_coded_time: total_coded_time_seconds # Actual coded time for the user for the day
      }
    end

    # Order @users_with_timeline_data according to @selected_user_ids
    # This ensures that if a user was explicitly selected they appear in the timeline
    # even if they have no heartbeats for the day.
    data_map_for_ordering = @users_with_timeline_data_unordered.index_by { |data| data[:user].id }
    @users_with_timeline_data = @selected_user_ids.map do |id|
      data_map_for_ordering[id] || (users_by_id[id] ? { user: users_by_id[id], spans: [], total_coded_time: 0 } : nil)
    end.compact

    # For Stimulus: provide initial selected users with details
    @initial_selected_user_objects = User.where(id: @selected_user_ids)
                                        .select(:id, :username, :slack_username, :github_username, :slack_avatar_url, :github_avatar_url)
                                        .map { |u| { id: u.id, display_name: "#{u.display_name}", avatar_url: u.avatar_url } }
                                        .sort_by { |u_obj| @selected_user_ids.index(u_obj[:id]) || Float::INFINITY } # Preserve order

    @primary_user = @users_with_timeline_data.first&.[](:user) || current_user



    # Get commit markers for timeline
    commits_for_timeline = Commit.where(
      user_id: @selected_user_ids,
      created_at: @date.beginning_of_day..@date.end_of_day
    )

    @timeline_commit_markers = commits_for_timeline.map do |commit|
      raw = commit.github_raw || {}
      # Use committer date if available, else fallback to created_at
      commit_time = if raw.dig("commit", "committer", "date")
        Time.parse(raw["commit"]["committer"]["date"])
      else
        commit.created_at
      end
      {
        user_id: commit.user_id,
        timestamp: commit_time.to_f,
        additions: (raw["stats"] && raw["stats"]["additions"]) || raw.dig("files", 0, "additions"),
        deletions: (raw["stats"] && raw["stats"]["deletions"]) || raw.dig("files", 0, "deletions"),
        github_url: raw["html_url"]
      }
    end

    render :show # Renders app/views/admin/timeline/show.html.erb
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
                  .order(Arel.sql("CASE WHEN LOWER(username) = #{ActiveRecord::Base.connection.quote(query_term)} THEN 0 ELSE 1 END, username ASC")) # Prioritize exact match
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
    start_date = Date.current # Leaderboard job for :last_7_days uses Date.current as start_date

    leaderboard = Leaderboard.where.not(finished_generating_at: nil)
                             .find_by(start_date: start_date, period_type: leaderboard_period_type, deleted_at: nil)

    user_ids_from_leaderboard = leaderboard ? leaderboard.entries.order(total_seconds: :desc).limit(limit).pluck(:user_id) : []

    all_ids_to_fetch = user_ids_from_leaderboard.dup
    all_ids_to_fetch.unshift(current_user.id).uniq!

    users_data = User.where(id: all_ids_to_fetch)
                     .select(:id, :username, :slack_username, :github_username, :slack_avatar_url, :github_avatar_url)
                     .index_by(&:id)

    final_user_objects = []
    # Add admin first
    if admin_data = users_data[current_user.id]
      final_user_objects << { id: admin_data.id, display_name: "#{admin_data.display_name}", avatar_url: admin_data.avatar_url }
    end

    # Add leaderboard users, ensuring no duplicates and respecting limit
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
