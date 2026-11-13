# The page that asks an unlinked account to link a Hack Club account.
# InertiaController#require_hca_link sends sessions here.
class HCALinkPromptsController < InertiaController
  layout "inertia"

  skip_before_action :require_hca_link
  before_action :require_unlinked_user

  def show
    render inertia: "Auth/LinkHackClub", props: {
      skippable: skippable?,
      continue_param: continue_url
    }
  end

  # "Not now".
  def destroy
    return redirect_to(hca_link_prompt_path(continue: continue_url)) unless skippable?

    session.delete(:hca_link_prompt)
    redirect_to continue_url || root_path
  end

  private

  def inertia_layout_props
    super.merge(hide_sidebar: true, hide_footer: true)
  end

  def continue_url = safe_return_url(params[:continue])

  def skippable? = !hca_link_required? || HCATransition.skippable?

  def require_unlinked_user
    return redirect_to(signin_path(continue: continue_url)) unless current_user

    redirect_to(continue_url || root_path) if current_user.hca_id.present? # codeql[rb/url-redirection]
  end
end
