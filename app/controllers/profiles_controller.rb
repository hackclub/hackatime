class ProfilesController < InertiaController
  layout "inertia"

  before_action :find_user
  before_action :check_profile_visibility, only: %i[time_stats projects languages editors activity]

  def show
    if @user.nil?
      render inertia: "Errors/NotFound", props: {
        status_code: 404,
        title: "Page Not Found",
        message: "The profile you were looking for doesn't exist."
      }, status: :not_found
      return
    end

    @is_own_profile = current_user.present? && current_user.id == @user.id
    @profile_visible = @user.allow_public_stats_lookup || @is_own_profile

    render inertia: "Profiles/Show", props: profile_props
  end

  def time_stats
    Time.use_zone(@user.timezone) do
      stats = ProfileStatsService.new(@user).stats
      render partial: "profiles/time_stats", locals: {
        total_time_today: stats[:total_time_today],
        total_time_week: stats[:total_time_week],
        total_time_all: stats[:total_time_all]
      }
    end
  end

  def projects
    Time.use_zone(@user.timezone) do
      stats = ProfileStatsService.new(@user).stats
      render partial: "profiles/projects", locals: { projects: stats[:top_projects_month] }
    end
  end

  def languages
    Time.use_zone(@user.timezone) do
      stats = ProfileStatsService.new(@user).stats
      render partial: "profiles/languages", locals: { languages: stats[:top_languages] }
    end
  end

  def editors
    Time.use_zone(@user.timezone) do
      stats = ProfileStatsService.new(@user).stats
      render partial: "profiles/editors", locals: { editors: stats[:top_editors] }
    end
  end

  def activity
    Time.use_zone(@user.timezone) do
      daily_durations = @user.heartbeats.daily_durations(user_timezone: @user.timezone).to_h
      render partial: "profiles/activity", locals: { daily_durations: daily_durations, user_tz: @user.timezone }
    end
  end

  private

  def find_user
    @user = User.find_by(username: params[:username])
  end

  def profile_props
    {
      page_title: profile_page_title,
      profile_visible: @profile_visible,
      is_own_profile: @is_own_profile,
      edit_profile_path: (@is_own_profile ? my_settings_profile_path : nil),
      profile: profile_summary_payload,
      stats: (@profile_visible ? profile_stats_payload : nil)
    }
  end

  def profile_page_title
    username = @user.username.present? ? "@#{@user.username}" : @user.display_name
    "#{username} | Hackatime"
  end

  def profile_summary_payload
    {
      display_name: @user.display_name_override.presence || @user.display_name,
      username: (@user.username || ""),
      avatar_url: @user.avatar_url,
      trust_level: @user.trust_level,
      bio: @user.profile_bio,
      social_links: profile_social_links,
      github_profile_url: @user.github_profile_url,
      github_username: @user.github_username,
      streak_days: (@profile_visible ? @user.streak_days : nil)
    }
  end

  def profile_social_links
    links = []

    links << { key: "github", label: "GitHub", url: @user.profile_github_url } if @user.profile_github_url.present?
    links << { key: "twitter", label: "Twitter", url: @user.profile_twitter_url } if @user.profile_twitter_url.present?
    links << { key: "bluesky", label: "Bluesky", url: @user.profile_bluesky_url } if @user.profile_bluesky_url.present?
    links << { key: "linkedin", label: "LinkedIn", url: @user.profile_linkedin_url } if @user.profile_linkedin_url.present?
    links << { key: "discord", label: "Discord", url: @user.profile_discord_url } if @user.profile_discord_url.present?
    links << { key: "website", label: "Website", url: @user.profile_website_url } if @user.profile_website_url.present?

    links
  end

  def profile_stats_payload
    h = ApplicationController.helpers
    timezone = @user.timezone
    stats = ProfileStatsService.new(@user).stats

    durations = Rails.cache.fetch("user_#{@user.id}_daily_durations_#{timezone}", expires_in: 1.minute) do
      Time.use_zone(timezone) { @user.heartbeats.daily_durations(user_timezone: timezone).to_h }
    end

    {
      totals: {
        today_seconds: stats[:total_time_today],
        week_seconds: stats[:total_time_week],
        all_seconds: stats[:total_time_all],
        today_label: h.short_time_simple(stats[:total_time_today]),
        week_label: h.short_time_simple(stats[:total_time_week]),
        all_label: h.short_time_simple(stats[:total_time_all])
      },
      top_projects_month: stats[:top_projects_month].map { |project|
        {
          project: project[:project],
          duration_seconds: project[:duration],
          duration_label: h.short_time_simple(project[:duration]),
          repo_url: project[:repo_url]
        }
      },
      top_languages: stats[:top_languages].map { |language, duration|
        [ h.display_language_name(language), duration ]
      },
      top_editors: stats[:top_editors].map { |editor, duration|
        [ h.display_editor_name(editor), duration ]
      },
      activity_graph: {
        start_date: 365.days.ago.to_date.iso8601,
        end_date: Time.current.to_date.iso8601,
        duration_by_date: durations.transform_keys { |date| date.to_date.iso8601 }.transform_values(&:to_i),
        busiest_day_seconds: 8.hours.to_i,
        timezone_label: ActiveSupport::TimeZone[timezone].to_s,
        timezone_settings_path: "/my/settings#user_timezone"
      }
    }
  end

  def check_profile_visibility
    return if @user.nil?

    is_own_profile = current_user && current_user.id == @user.id
    profile_visible = @user.allow_public_stats_lookup || is_own_profile

    head :not_found unless profile_visible
  end
end
