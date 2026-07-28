class ApiKeysController < InertiaController
  layout "inertia", only: [ :show ]

  before_action :authenticate_user!

  def show
    api_key = current_user.api_keys.first || current_user.api_keys.create!(name: "Hackatime key")

    render inertia: "ApiKey/Show", props: {
      api_key: api_key.token
    }
  end

  private

  def inertia_layout_props
    super.merge(hide_footer: true)
  end
end
