class ApiKeysController < InertiaController
  layout "inertia", only: [ :show ]

  before_action :authenticate_user!

  def show
    api_key = current_user.hackatime_api_key(create_if_missing: true)

    render inertia: "ApiKey/Show", props: {
      api_key: api_key.token
    }
  end

  private

  def inertia_layout_props
    super.merge(hide_footer: true)
  end
end
