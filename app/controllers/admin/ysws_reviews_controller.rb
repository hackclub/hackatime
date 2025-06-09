class Admin::YswsReviewsController < Admin::BaseController
  include ApplicationHelper

  before_action :set_submission, only: [ :show ]

  def show
  end

  private

  def set_submission
    @submission = Neighborhood::YswsSubmission.find_by(airtable_id: params[:record_id])
    ensure_exists @submission
    @app = @submission.app
    ensure_exists @app
    @posts = @app.posts
  end

  def ensure_exists(value)
    unless value.present?
      object_name = value.nil? ? "Record" : value.class.name.demodulize
      redirect_to admin_timeline_path, alert: "#{object_name} not found."
    end
  end
end
