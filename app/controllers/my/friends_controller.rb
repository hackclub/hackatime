module My
  class FriendsController < ApplicationController
    before_action :ensure_current_user

    def index
      @user = current_user
      @tab = params[:tab] || "currently_hacking"
      
      case @tab
      when "currently_hacking"
        @currently_hacking_friends = get_currently_hacking_friends
      when "all"
        @friends = User.joins("INNER JOIN follows ON follows.to_id = users.id")
                       .where("follows.from_id = ?", current_user.id)
                       .where("EXISTS (SELECT 1 FROM follows f2 WHERE f2.from_id = follows.to_id AND f2.to_id = ?)", current_user.id)
      when "pending"
        @show_ignored_incoming = params[:show_ignored_incoming] == "true"
        @show_unrequited_outgoing = params[:show_unrequited_outgoing] == "true"
        
        @incoming_requests = get_incoming_requests
        @outgoing_requests = get_outgoing_requests
        @incoming_count = get_incoming_count
      when "pending_count"
        render json: { count: get_incoming_count }
        return
      when "add_friend"
      end

      if turbo_frame_request?
        render partial: "friends_tab_content", layout: false, 
               locals: { tab: @tab }
        return
      end
    end

    def search_users
      query_term = params[:query].to_s.downcase
      
      existing_friend_ids = Follow.where(from_id: current_user.id, ignored: false).pluck(:to_id)
      excluded_ids = [current_user.id] + existing_friend_ids

      user_id_match = nil
      if query_term.match?(/^\d+$/)
        user_id = query_term.to_i
        user_id_match = User.where(id: user_id).where.not(id: excluded_ids).first
      end

      if user_id_match
        results = [{
          id: user_id_match.id,
          display_name: user_id_match.display_name,
          avatar_url: user_id_match.avatar_url
        }]
      else
        users = User.where("LOWER(username) LIKE :query OR LOWER(slack_username) LIKE :query OR CAST(id AS TEXT) LIKE :query OR EXISTS (SELECT 1 FROM email_addresses WHERE email_addresses.user_id = users.id AND LOWER(email_addresses.email) LIKE :query)", query: "%#{query_term}%")
                    .where.not(id: excluded_ids)
                    .order(Arel.sql("CASE WHEN LOWER(username) = #{ActiveRecord::Base.connection.quote(query_term)} THEN 0 ELSE 1 END, username ASC"))
                    .limit(20)
                    .select(:id, :username, :slack_username, :github_username, :slack_avatar_url, :github_avatar_url)

        results = users.map do |user|
          {
            id: user.id,
            display_name: user.display_name,
            avatar_url: user.avatar_url
          }
        end
      end

      render json: results
    end

    def create
      friend_id = params[:friend_id].to_i
      friend = User.find_by(id: friend_id)
      
      if friend.nil?
        render json: { error: "User not found" }, status: :not_found
        return
      end

      if friend.id == current_user.id
        render json: { error: "You cannot add yourself as a friend" }, status: :bad_request
        return
      end

      existing_follow = Follow.find_by(from_id: current_user.id, to_id: friend.id)
      
      if existing_follow
        if existing_follow.ignored?
          existing_follow.update!(ignored: false)
          render json: { success: true, message: "Friend added successfully" }
        else
          render json: { error: "Already following this user" }, status: :bad_request
        end
      else
        Follow.create!(from_id: current_user.id, to_id: friend.id, ignored: false)
        render json: { success: true, message: "Friend added successfully" }
      end
    end

    def destroy
      friend_id = params[:friend_id].to_i
      friend = User.find_by(id: friend_id)
      
      if friend.nil?
        render json: { error: "User not found" }, status: :not_found
        return
      end

      existing_follow = Follow.find_by(from_id: current_user.id, to_id: friend.id)
      
      if existing_follow && !existing_follow.ignored?
        existing_follow.update!(ignored: true)
        render json: { success: true, message: "Friend removed successfully" }
      else
        render json: { error: "Not following this user" }, status: :bad_request
      end
    end

    def accept_request
      requester_id = params[:requester_id].to_i
      requester = User.find_by(id: requester_id)
      
      if requester.nil?
        render json: { error: "User not found" }, status: :not_found
        return
      end

      incoming_follow = Follow.find_by(from_id: requester_id, to_id: current_user.id, ignored: false)
      
      if incoming_follow.nil?
        render json: { error: "No pending request from this user" }, status: :bad_request
        return
      end
      existing_reverse = Follow.find_by(from_id: current_user.id, to_id: requester_id)
      
      if existing_reverse
        existing_reverse.update!(ignored: false)
      else
        Follow.create!(from_id: current_user.id, to_id: requester_id, ignored: false)
      end

      render json: { success: true, message: "Friend request accepted" }
    end

    def ignore_request
      requester_id = params[:requester_id].to_i
      
      incoming_follow = Follow.find_by(from_id: requester_id, to_id: current_user.id, ignored: false)
      
      if incoming_follow.nil?
        render json: { error: "No pending request from this user" }, status: :bad_request
        return
      end

      incoming_follow.update!(ignored: true)
      render json: { success: true, message: "Friend request ignored" }
    end

    def cancel_request
      recipient_id = params[:recipient_id].to_i
      
      outgoing_follow = Follow.find_by(from_id: current_user.id, to_id: recipient_id, ignored: false)
      
      if outgoing_follow.nil?
        render json: { error: "No outgoing request to this user" }, status: :bad_request
        return
      end

      outgoing_follow.destroy!
      render json: { success: true, message: "Friend request cancelled" }
    end

    private

    def ensure_current_user
      redirect_to root_path, alert: "You must be logged in to view this page" unless current_user
    end

    def get_currently_hacking_friends
      friend_ids = Follow.where(from_id: current_user.id)
                         .where("EXISTS (SELECT 1 FROM follows f2 WHERE f2.from_id = follows.to_id AND f2.to_id = ?)", current_user.id)
                         .pluck(:to_id)
      return [] if friend_ids.empty?
      recent_heartbeats = Heartbeat.joins(:user)
                                  .where(user_id: friend_ids)
                                  .where(source_type: :direct_entry)
                                  .coding_only
                                  .where("time > ?", 5.minutes.ago.to_f)
                                  .select("DISTINCT ON (user_id) user_id, project, time, users.*")
                                  .order("user_id, time DESC")
                                  .includes(user: :project_repo_mappings)
                                  .index_by(&:user_id)

      currently_hacking_friends = recent_heartbeats.values.map(&:user)
      
      @active_projects = {}
      currently_hacking_friends.each do |user|
        recent_heartbeat = recent_heartbeats[user.id]
        @active_projects[user.id] = user.project_repo_mappings.find { |p| p.project_name == recent_heartbeat&.project }
      end
      currently_hacking_friends.sort_by do |user|
        [
          @active_projects[user.id].present? ? 0 : 1,
          user.username.present? ? 0 : 1,
          user.slack_username.present? ? 0 : 1,
          user.github_username.present? ? 0 : 1
        ]
      end
    end

    def get_incoming_requests
      ignored_condition = @show_ignored_incoming ? "" : " AND follows.ignored = false"
      
      Follow.joins("INNER JOIN users ON users.id = follows.from_id")
            .where("follows.to_id = ?#{ignored_condition}", current_user.id)
            .where("NOT EXISTS (SELECT 1 FROM follows f2 WHERE f2.from_id = ? AND f2.to_id = follows.from_id)", current_user.id)
            .includes(:from)
            .map { |follow| { follow: follow, user: follow.from } }
    end

    def get_outgoing_requests
      if @show_unrequited_outgoing
        Follow.joins("INNER JOIN users ON users.id = follows.to_id")
              .where("follows.from_id = ?", current_user.id)
              .where("NOT EXISTS (SELECT 1 FROM follows f2 WHERE f2.from_id = follows.to_id AND f2.to_id = ?)", current_user.id)
              .includes(:to)
              .map { |follow| { follow: follow, user: follow.to } }
      else
        Follow.joins("INNER JOIN users ON users.id = follows.to_id")
              .where("follows.from_id = ? AND follows.ignored = false", current_user.id)
              .where("NOT EXISTS (SELECT 1 FROM follows f2 WHERE f2.from_id = follows.to_id AND f2.to_id = ?)", current_user.id)
              .includes(:to)
              .map { |follow| { follow: follow, user: follow.to } }
      end
    end

    def get_incoming_count
      Follow.where(to_id: current_user.id, ignored: false)
            .where("NOT EXISTS (SELECT 1 FROM follows f2 WHERE f2.from_id = ? AND f2.to_id = follows.from_id AND f2.ignored = false)", current_user.id)
            .count
    end
  end
end
