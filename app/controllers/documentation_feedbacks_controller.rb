class DocumentationFeedbacksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    feedback = DocumentationFeedback.find_or_initialize_by(identity.merge(path: feedback_params[:path]))
    feedback.assign_attributes(feedback_params.slice(:helpful, :title))
    feedback.save!

    head feedback.previously_new_record? ? :created : :no_content
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid
    render json: { error: "Invalid feedback" }, status: :unprocessable_entity
  end

  private

  def feedback_params
    @feedback_params ||= params.permit(:helpful, :path, :title).tap do |permitted|
      permitted.require([ :helpful, :path, :title ])
    end
  end

  def identity
    return { user: current_user } if current_user

    { visitor_token: params.require(:visitor_token) }
  end
end
