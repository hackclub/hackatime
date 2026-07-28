class ExtensionsController < InertiaController
  layout "inertia"

  def index
    render inertia: "Extensions/Index"
  end
end
