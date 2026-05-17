class ApiKeyController < InertiaController
  layout "inertia", only: [ :show ]

  before_action :require_login

  def show
    api_key = current_user.api_keys.order(created_at: :desc).first || current_user.api_keys.create!(name: "Hackatime key")

    render inertia: "ApiKey/Show", props: {
      api_key: api_key.token
    }
  end

  private

  def require_login
    return if current_user
    redirect_to signin_path(continue: request.fullpath),
                alert: "You must be signed in to view your API key."
  end

  def inertia_layout_props
    super.merge(hide_footer: true)
  end
end
