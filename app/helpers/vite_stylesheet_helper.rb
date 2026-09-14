module ViteStylesheetHelper
  def vite_entrypoint_stylesheet_tag(name, type: :stylesheet, **options)
    paths = if type == :stylesheet
      [ vite_manifest.path_for(name, type:) ]
    else
      vite_manifest.resolve_entries(name, type:).fetch(:stylesheets)
    end

    stylesheet_link_tag(*paths, **options)
  end
end
