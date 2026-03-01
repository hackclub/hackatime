class WeeklySummaryMailer < ApplicationMailer
  helper :application

  def weekly_summary(user, recipient_email:, starts_at:, ends_at:)
    @user = user
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

    @total_seconds = coding_heartbeats.duration_seconds
    @daily_average_seconds = (@total_seconds / 7.0).round
    @total_heartbeats = coding_heartbeats.count
    @active_days = active_days_count(coding_heartbeats)
    @top_projects = breakdown(coding_heartbeats, :project)
    @top_languages = breakdown(coding_heartbeats, :language)

    mail(
      to: recipient_email,
      subject: "Your Hackatime weekly summary (#{@subject_period_label})"
    )
  end

  private

  def breakdown(scope, column, limit: 5)
    scope.group(column)
      .duration_seconds
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
end
