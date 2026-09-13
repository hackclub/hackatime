module ViteStylesheetHelper
  STYLESHEET_CONTENT = Concurrent::Map.new

  def inline_vite_stylesheet_tag(name, type: :stylesheet)
    return if ViteRuby.instance.dev_server_running?

    paths = if type == :stylesheet
      [ vite_manifest.path_for(name, type:) ]
    else
      vite_manifest.resolve_entries(name, type:).fetch(:stylesheets)
    end

    css = paths.filter_map { |path| vite_stylesheet_content(path) }.join("\n")
    return if css.empty?

    content_tag(
      :style,
      css.html_safe,
      data: { initial_vite_stylesheet: name },
      nonce: content_security_policy_nonce
    )
  end

  private

  def vite_stylesheet_content(path)
    asset_path = Rails.root.join(ViteRuby.config.public_dir, path.delete_prefix("/"))
    STYLESHEET_CONTENT.compute_if_absent(asset_path.to_s) { asset_path.binread }
  end
end
