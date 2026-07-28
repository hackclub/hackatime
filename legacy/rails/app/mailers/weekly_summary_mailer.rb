class WeeklySummaryMailer < ApplicationMailer
  helper :application

  def weekly_summary(user, recipient_email:, starts_at:, ends_at:)
    @user = user
    @unsubscribe_url = mailkick_unsubscribe_url(@user, "weekly_summary")
    user_tz = ActiveSupport::TimeZone[@user.timezone]
    @timezone = user_tz || ActiveSupport::TimeZone["UTC"]
    @timezone_label = user_tz ? @user.timezone : @timezone.tzinfo.identifier
    @starts_at = starts_at.utc
    @ends_at = ends_at.utc
    @starts_at_local = @starts_at.in_time_zone(@timezone)
    @ends_at_local = @ends_at.in_time_zone(@timezone)
    @subject_period_label = "#{@starts_at_local.strftime("%b %-d")} - #{@ends_at_local.strftime("%b %-d, %Y")}"
    @period_label = @subject_period_label

    coding_heartbeats = @user.heartbeats.where(time: @starts_at.to_f...@ends_at.to_f)
    @total_seconds = coding_heartbeats.duration_seconds
    num_days = [ (@ends_at - @starts_at) / 1.day, 1 ].max
    @daily_average_seconds = (@total_seconds / num_days).round
    @total_heartbeats = coding_heartbeats.count
    @active_days = active_days_count(coding_heartbeats)
    @top_projects = breakdown(coding_heartbeats.group(:project).duration_seconds, default_name: "Other")
    @top_languages = breakdown(Heartbeat.attributed_durations_by(coding_heartbeats, :language))

    mail(to: recipient_email, subject: "Your Hackatime weekly summary (#{@subject_period_label})")
  end

  private

  def breakdown(pairs, limit: 5, default_name: nil)
    pairs.sort_by { |_n, s| -s.to_i }.first(limit).map do |name, seconds|
      { name: default_name ? (name.presence || default_name) : name,
        seconds: seconds.to_i,
        duration_label: ApplicationController.helpers.short_time_simple(seconds) }
    end
  end

  def active_days_count(scope)
    timezone_sql = ActiveRecord::Base.connection.quote(@timezone_label)
    scope.where.not(time: nil).distinct.count(Arel.sql("DATE(to_timestamp(time) AT TIME ZONE #{timezone_sql})"))
  rescue StandardError
    scope.where.not(time: nil).pluck(:time).map { |t| Time.at(t).in_time_zone(@timezone_label).to_date }.uniq.count
  end
end
