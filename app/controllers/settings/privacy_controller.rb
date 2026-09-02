class Settings::PrivacyController < Settings::BaseController
  def update
    update_user_settings(privacy_params, redirect_location: my_settings_privacy_path, back: true)
  end

  def rotate_api_key
    new_api_key = @user.rotate_api_keys!
    flash[:rotated_api_key] = new_api_key.token
    redirect_to my_settings_privacy_path, notice: "API key rotated successfully"
  rescue => e
    report_error(e, message: "error rotate #{e.class.name}")
    redirect_to my_settings_privacy_path, alert: "Unable to rotate API key"
  end

  def revoke_application
    OauthApplication.revoke_tokens_and_grants_for(params[:application_id], @user)
    redirect_to my_settings_privacy_path, notice: "Application access revoked"
  end

  private

  def page_props
    { user: {
        allow_public_stats_lookup: @user.allow_public_stats_lookup,
        can_request_deletion: @user.can_request_deletion?
      },
      rotated_api_key: flash[:rotated_api_key],
      authorized_applications: OauthApplication.authorized_for(@user).map { |application|
        { id: application.id, name: application.name,
          authorized_at: "#{helpers.time_ago_in_words(application.created_at)} ago" }
      },
      deletion_reason_details_max_length: DeletionRequest::MAX_REASON_DETAILS_LENGTH }
  end

  def privacy_params = params.require(:user).permit(:allow_public_stats_lookup)
end
