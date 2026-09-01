class ExtensionsController < InertiaController
  def index
    render inertia: "Extensions/Index"
  end
end
