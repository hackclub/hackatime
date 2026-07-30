class DocumentationFeedbacksController < ApplicationController
  skip_before_action :verify_authenticity_token

  def create
    return head :forbidden unless same_origin_json_request?
    return render_invalid_feedback unless [ true, false ].include?(params[:helpful])

    key = identity.merge(path: canonical_path)
    feedback = DocumentationFeedback.find_by(key)
    feedback ||= DocumentationFeedback.create_or_find_by!(key) do |record|
      record.assign_attributes(feedback_attributes)
    end
    created = feedback.previously_new_record?
    feedback.update!(feedback_attributes) unless created

    head created ? :created : :no_content
  rescue ActionController::ParameterMissing, ActiveRecord::RecordInvalid
    render_invalid_feedback
  end

  private

  def canonical_path
    params.require(:path).sub(%r{/+\z}, "").presence || "/"
  end

  def feedback_attributes
    { helpful: params.require(:helpful), title: params.require(:title) }
  end

  def identity
    return { user: current_user } if current_user

    { visitor_token: params.require(:visitor_token).downcase }
  end

  def same_origin_json_request?
    request.media_type == "application/json" && request.origin == request.base_url
  end

  def render_invalid_feedback
    render json: { error: "Invalid feedback" }, status: :unprocessable_entity
  end
end
