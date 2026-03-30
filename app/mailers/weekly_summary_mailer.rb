class WeeklySummaryMailer < ApplicationMailer
  helper :application

  def weekly_summary(user, recipient_email:, starts_at:, ends_at:)
    @user = user
    @unsubscribe_url = mailkick_unsubscribe_url(@user, "weekly_summary")
    user_timezone = ActiveSupport::TimeZone[@user.timezone]
    @timezone = user_timezone || ActiveSupport::TimeZone["UTC"]
    @timezone_label = user_timezone ? @user.timezone : @timezone.tzinfo.identifier
    @starts_at = starts_at.utc
    @ends_at = ends_at.utc
    @starts_at_local = @starts_at.in_time_zone(@timezone)
    @ends_at_local = @ends_at.in_time_zone(@timezone)
    @subject_period_label = "#{@starts_at_local.strftime("%b %-d")} - #{@ends_at_local.strftime("%b %-d, %Y")}"
    @period_label = @subject_period_label

    coding_heartbeats = @user.heartbeats.where(time: @starts_at.to_f...@ends_at.to_f)

    @total_seconds = StatsClient.duration(
      user_id: @user.id,
      start_time: @starts_at.to_f,
      end_time: stats_end_time
    )["total_seconds"].to_i
    num_days = [ (@ends_at - @starts_at) / 1.day, 1 ].max
    @daily_average_seconds = (@total_seconds / num_days).round
    @total_heartbeats = coding_heartbeats.count
    @active_days = active_days_count(coding_heartbeats)
    @top_projects = breakdown(:project)
    @top_languages = breakdown(:language)

    mail(
      to: recipient_email,
      subject: "Your Hackatime weekly summary (#{@subject_period_label})"
    )
  end

  private

  def breakdown(column, limit: 5)
    (StatsClient.duration_grouped(
      group_by: column.to_s,
      user_id: @user.id,
      start_time: @starts_at.to_f,
      end_time: stats_end_time,
      limit: limit
    )["groups"] || {})
      .sort_by { |_name, seconds| -seconds.to_i }
      .first(limit)
      .map do |name, seconds|
      {
        name: name.presence || "Other",
        seconds: seconds.to_i,
        duration_label: ApplicationController.helpers.short_time_simple(seconds)
      }
    end
  end

  def active_days_count(scope)
    timezone = @timezone_label
    timezone_sql = ActiveRecord::Base.connection.quote(timezone)
    scope.where.not(time: nil)
      .distinct
      .count(Arel.sql("DATE(to_timestamp(time) AT TIME ZONE #{timezone_sql})"))
  rescue StandardError
    scope.where.not(time: nil).pluck(:time).map { |time| Time.at(time).in_time_zone(timezone).to_date }.uniq.count
  end

  def stats_end_time
    @stats_end_time ||= @ends_at.to_f - 1e-6
  end
end
