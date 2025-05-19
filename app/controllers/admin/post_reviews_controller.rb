# app/controllers/admin/post_reviews_controller.rb
class Admin::PostReviewsController < Admin::BaseController
  include ApplicationHelper

  before_action :set_post, only: [ :show ]

  def show
    slack_uid = @post.airtable_fields["slackId"]&.first
    @user = User.find_by(slack_uid: slack_uid)
    ensure_exists @user

    @target_user_timezone = @user.timezone
    @project_repo_mappings_for_user = @user.project_repo_mappings.index_by(&:project_name)

    begin
      post_start_str = @post.airtable_fields["lastPost"]
      post_end_str = @post.airtable_fields["createdAt"]

      if post_start_str.blank? || post_end_str.blank?
        raise ArgumentError, "Post start or end date is missing from Airtable. lastPost: '#{post_start_str}', createdAt: '#{post_end_str}'"
      end

      post_start_utc = Time.zone.parse(post_start_str)
      post_end_utc = Time.zone.parse(post_end_str)
    rescue ArgumentError, TypeError => e
      Rails.logger.error "Failed to parse post dates from Airtable for post #{@post.id} (User: #{@user.id}): #{e.message}"
      flash[:alert] = "Could not parse post dates for post ID #{@post.airtable_id}. Please check Airtable data. Error: #{e.message}"
      @review_start_date = Date.current - 1.day
      @review_end_date = Date.current + 1.day
      @post_start_display = Time.current
      @post_end_display = Time.current
      @commits = []
      @detailed_spans = []
      render and return
    end

    @post_start_display = post_start_utc.in_time_zone(@target_user_timezone)
    @post_end_display = post_end_utc.in_time_zone(@target_user_timezone)

    @review_start_date = (@post_start_display.to_date - 1.day)
    @review_end_date = (@post_end_display.to_date + 1.day)

    query_start_utc = @review_start_date.in_time_zone(@target_user_timezone).beginning_of_day.utc
    query_end_utc = @review_end_date.in_time_zone(@target_user_timezone).end_of_day.utc

    @commits = Commit.where(user: @user, created_at: query_start_utc..query_end_utc).order(created_at: :asc)

    # Calculate detailed spans
    all_heartbeats_for_user_in_review_window = Heartbeat
      .where(user: @user, time: query_start_utc.to_f..query_end_utc.to_f)
      .select(:id, :user_id, :time, :entity, :project, :editor, :language)
      .order(:time)
      .to_a

    @detailed_spans = []
    if all_heartbeats_for_user_in_review_window.any?
      current_span_heartbeats = []
      timeout_duration = 10.minutes.to_i

      all_heartbeats_for_user_in_review_window.each_with_index do |heartbeat, index|
        current_span_heartbeats << heartbeat
        is_last_heartbeat = (index == all_heartbeats_for_user_in_review_window.length - 1)
        time_to_next = is_last_heartbeat ? Float::INFINITY : (all_heartbeats_for_user_in_review_window[index + 1].time - heartbeat.time)

        if time_to_next > timeout_duration || is_last_heartbeat
          if current_span_heartbeats.any?
            start_time_numeric = current_span_heartbeats.first.time
            last_hb_time_numeric = current_span_heartbeats.last.time

            actual_coded_duration_seconds = Heartbeat.where(id: current_span_heartbeats.map(&:id)).duration_seconds

            files = current_span_heartbeats.map { |h| h.entity&.split("/")&.last }.compact.uniq.sort

            projects_details_for_span = []
            unique_project_names = current_span_heartbeats.map(&:project).compact.reject(&:blank?).uniq

            unique_project_names.each do |p_name|
              repo_mapping = @project_repo_mappings_for_user[p_name]
              projects_details_for_span << {
                name: p_name,
                repo_url: repo_mapping&.repo_url
              }
            end

            editors = current_span_heartbeats.map(&:editor).compact.uniq.sort
            languages = current_span_heartbeats.map(&:language).compact.uniq.sort

            @detailed_spans << {
              start_time: start_time_numeric,
              end_time: last_hb_time_numeric,
              duration: actual_coded_duration_seconds,
              files_edited: files,
              projects_edited_details: projects_details_for_span.sort_by { |p| p[:name].downcase },
              editors: editors,
              languages: languages
            }
            current_span_heartbeats = []
          end
        end
      end
    end

    @current_user_timezone = current_user.timezone
  end

  private

  def set_post
    @post = Neighborhood::Post.find_by(airtable_id: params[:post_id])
    ensure_exists @post
  end

  def ensure_exists(value)
    unless value.present?
      object_name = value.nil? ? "Record" : value.class.name.demodulize
      redirect_to admin_timeline_path, alert: "#{object_name} not found."
    end
  end
end
