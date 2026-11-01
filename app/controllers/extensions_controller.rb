class ExtensionsController < InertiaController
  layout "inertia"

  def index
    use_og_page(:extensions)
    render inertia: "Extensions/Index", props: { page_title: @page_title }
  end
end
