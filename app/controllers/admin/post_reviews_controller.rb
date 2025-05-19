class Admin::PostReviewsController < Admin::BaseController
  before_action :set_post, only: [ :show ]

  def show
    post_start = @post.airtable_fields["lastPost"]
    post_end = @post.airtable_fields["createdAt"]

    review_start_date = post_start.to_date.beginning_of_day - 1.day
    review_end_date = post_end.to_date.end_of_day + 1.day

    slack_uid = @post.airtable_fields["slackId"].first
    user = User.find_by(slack_uid: slack_uid)
    ensure_exists user

    @commits = Commit.where(user: user, created_at: review_start_date..review_end_date)

    @spans = Heartbeat.where(user: user, time: review_start_date..review_end_date).to_span

    @current_user_timezone = current_user.timezone
    @target_user_timezone = user.timezone

    render json: {
      commits: @commits,
      spans: @spans,
      post: @post,
      post_start: post_start,
      post_end: post_end,
      review_start_date: review_start_date,
      review_end_date: review_end_date,
      user: user,
      current_user_timezone: @current_user_timezone,
      target_user_timezone: @target_user_timezone
    }
  end

  private

  def set_post
    @post = Neighborhood::Post.find_by(airtable_id: params[:post_id])
    ensure_exists @post
  end

  def ensure_exists(value)
    unless value.present?
      render plain: "Not found", status: :not_found
    end
  end
end
