module Api
  module V1
    class BadgesController < ApplicationController
      skip_before_action :verify_authenticity_token

      # GET /api/v1/badge/:user_id/*project
      #
      # Generates a shields.io badge showing coding time for a project.
      # Supports lookup by slack_uid, username, or internal id.
      # Project can be a project name ("hackatime") or owner/repo ("hackclub/hackatime").
      def show
        user = find_user(params[:user_id])
        return render json: { error: "User not found" }, status: :not_found unless user

        unless user.allow_public_stats_lookup
          return render json: { error: "User has disabled public stats" }, status: :forbidden
        end

        project_name = resolve_project_name(user, params[:project])
        return render json: { error: "Project not found" }, status: :not_found unless project_name

        seconds = StatsClient.duration(user_id: user.id, project: project_name)["total_seconds"].to_i
        return head :bad_request if seconds <= 0

        label = params[:label] || "hackatime"
        color = params[:color] || "blue"

        time_text = format_duration(seconds)
        shields_url = "https://img.shields.io/badge/#{ERB::Util.url_encode(label)}-#{ERB::Util.url_encode(time_text)}-#{ERB::Util.url_encode(color)}"

        # Pass through any extra shields.io params (style, logo, etc.)
        extra = params.to_unsafe_h.except(:controller, :action, :user_id, :project, :label, :color, :aliases, :format)
        extra.each { |k, v| shields_url += "&#{ERB::Util.url_encode(k)}=#{ERB::Util.url_encode(v)}" }

        # Handle aliases (comma-separated project names to sum)
        if params[:aliases].present?
          alias_names = params[:aliases].split(",").map(&:strip) - [ project_name ]
          alias_seconds = StatsClient.duration(user_id: user.id, projects: alias_names)["total_seconds"].to_i
          seconds += alias_seconds

          # Recalculate with alias time included
          time_text = format_duration(seconds)
          shields_url = "https://img.shields.io/badge/#{ERB::Util.url_encode(label)}-#{ERB::Util.url_encode(time_text)}-#{ERB::Util.url_encode(color)}"
          extra.each { |k, v| shields_url += "&#{ERB::Util.url_encode(k)}=#{ERB::Util.url_encode(v)}" }
        end

        redirect_to shields_url, allow_other_host: true, status: :temporary_redirect
      end

      private

      def find_user(identifier)
        return nil if identifier.blank?

        User.find_by(slack_uid: identifier) ||
          User.find_by(username: identifier) ||
          (identifier.match?(/^\d+$/) && User.find_by(id: identifier))
      end

      # Resolve owner/repo format to a project name via ProjectRepoMapping
      def resolve_project_name(user, project_param)
        return nil if project_param.blank?

        # Direct match by project name first
        if user.heartbeats.where(project: project_param).exists?
          return project_param
        end

        # Try owner/repo → project_name lookup via repository
        if project_param.include?("/")
          mapping = user.project_repo_mappings
                        .joins(:repository)
                        .where(repositories: { owner: project_param.split("/", 2).first, name: project_param.split("/", 2).last })
                        .first
          return mapping.project_name if mapping
        end

        nil
      end

      def format_duration(seconds)
        hours = seconds / 3600
        minutes = (seconds % 3600) / 60
        hours > 0 ? "#{hours}h #{minutes}m" : "#{minutes}m"
      end
    end
  end
end
