class DocsController < InertiaController
  layout "inertia"

  POPULAR_EDITORS = [
    [ "VS Code", "vs-code" ], [ "PyCharm", "pycharm" ], [ "IntelliJ IDEA", "intellij-idea" ],
    [ "Sublime Text", "sublime-text" ], [ "Vim", "vim" ], [ "Neovim", "neovim" ],
    [ "Android Studio", "android-studio" ], [ "Xcode", "xcode" ], [ "Unity", "unity" ],
    [ "Godot", "godot" ], [ "Cursor", "cursor" ], [ "Zed", "zed" ],
    [ "Terminal", "terminal" ], [ "WebStorm", "webstorm" ], [ "Eclipse", "eclipse" ],
    [ "Emacs", "emacs" ], [ "Jupyter", "jupyter" ], [ "OnShape", "onshape" ]
  ].freeze

  ALL_EDITORS = [
    [ "Android Studio", "android-studio" ], [ "AppCode", "appcode" ], [ "Aptana", "aptana" ],
    [ "Arduino IDE", "arduino-ide" ], [ "Azure Data Studio", "azure-data-studio" ],
    [ "Brackets", "brackets" ],
    [ "C++ Builder", "c++-builder" ],
    [ "CLion", "clion" ], [ "Cloud9", "cloud9" ], [ "Coda", "coda" ],
    [ "CodeTasty", "codetasty" ], [ "Cursor", "cursor" ], [ "DataGrip", "datagrip" ],
    [ "DataSpell", "dataspell" ], [ "DBeaver", "dbeaver" ], [ "Delphi", "delphi" ],
    [ "Eclipse", "eclipse" ],
    [ "Emacs", "emacs" ], [ "Eric", "eric" ],
    [ "Figma", "figma" ], [ "Gedit", "gedit" ],
    [ "Godot", "godot" ], [ "GoLand", "goland" ], [ "HBuilder X", "hbuilder-x" ],
    [ "IntelliJ IDEA", "intellij-idea" ], [ "Jupyter", "jupyter" ],
    [ "Kakoune", "kakoune" ], [ "Kate", "kate" ], [ "Komodo", "komodo" ],
    [ "Micro", "micro" ], [ "MPS", "mps" ], [ "Neovim", "neovim" ],
    [ "NetBeans", "netbeans" ], [ "Notepad++", "notepad++" ], [ "Nova", "nova" ],
    [ "Obsidian", "obsidian" ], [ "OnShape", "onshape" ], [ "Oxygen", "oxygen" ],
    [ "PhpStorm", "phpstorm" ], [ "Postman", "postman" ],
    [ "Processing", "processing" ], [ "Pulsar", "pulsar" ], [ "PyCharm", "pycharm" ],
    [ "ReClassEx", "reclassex" ], [ "Rider", "rider" ], [ "Roblox Studio", "roblox-studio" ],
    [ "RubyMine", "rubymine" ], [ "RustRover", "rustrover" ],
    [ "SiYuan", "siyuan" ], [ "Sketch", "sketch" ], [ "SlickEdit", "slickedit" ],
    [ "SQL Server Management Studio", "sql-server-management-studio" ],
    [ "Sublime Text", "sublime-text" ], [ "Terminal", "terminal" ],
    [ "TeXstudio", "texstudio" ], [ "TextMate", "textmate" ], [ "Trae", "trae" ],
    [ "Unity", "unity" ], [ "Unreal Engine 4", "unreal-engine-4" ],
    [ "Vim", "vim" ], [ "Visual Studio", "visual-studio" ], [ "VS Code", "vs-code" ],
    [ "WebStorm", "webstorm" ], [ "Windsurf", "windsurf" ], [ "Wing", "wing" ],
    [ "Xcode", "xcode" ], [ "Zed", "zed" ],
    [ "Swift Playgrounds", "swift-playgrounds" ]
  ].sort_by { |editor| editor[0] }.freeze

  # Docs are publicly accessible - no authentication required

  def llms
    respond_to do |format|
      format.text { render layout: false }
    end
  end

  def llms_full
    respond_to do |format|
      format.text { render layout: false }
    end
  end

  def index
    render inertia: "Docs/Index", props: {
      popular_editors: POPULAR_EDITORS,
      all_editors: ALL_EDITORS
    }
  end

  def show
    doc_path = sanitize_path(params[:path] || "index")

    if doc_path.start_with?("api")
      redirect_to "/api-docs", allow_other_host: false and return
    end

    file_path = safe_docs_path("#{doc_path}.md")

    unless File.exist?(file_path)
      # Try with index.md in the directory
      dir_path = safe_docs_path(doc_path, "index.md")
      if File.exist?(dir_path)
        file_path = dir_path
      else
        render_not_found and return
      end
    end

    content = read_docs_file(file_path)
    title = extract_title(content) || doc_path.humanize
    rendered_content = render_markdown(content)
    breadcrumbs = build_inertia_breadcrumbs(doc_path)
    edit_url = "https://github.com/hackclub/hackatime/edit/main/docs/#{doc_path}.md"

    respond_to do |format|
      format.html do
        render inertia: "Docs/Show", props: {
          doc_path: doc_path,
          title: title,
          rendered_content: rendered_content,
          breadcrumbs: breadcrumbs,
          edit_url: edit_url,
          meta: {
            description: generate_doc_description(content, title),
            keywords: generate_doc_keywords(doc_path, title)
          }
        }
      end
      format.md { render plain: content, content_type: "text/markdown" }
    end
  rescue => e
    Rails.logger.error "Error loading docs: #{e.message}"
    render_not_found
  end

  private

  def sanitize_path(path)
    # Remove any directory traversal attempts and normalize path
    return "index" if path.blank?

    clean_path = path.to_s.split("/").reject(&:empty?).join("/").gsub("..", "")
    clean_path = clean_path.gsub(/[^a-zA-Z0-9\-_+\/]/, "")

    clean_path.present? ? clean_path : "index"
  end

  def safe_docs_path(*parts)
    # Build a safe path within the docs directory
    docs_root = Rails.root.join("docs")
    full_path = docs_root.join(*parts)

    # Ensure the path is within the docs directory
    unless full_path.to_s.start_with?(docs_root.to_s)
      raise ArgumentError, "Path traversal attempted"
    end

    full_path
  end

  def read_docs_file(file_path)
    # Safely read a file from the docs directory
    unless file_path.to_s.start_with?(Rails.root.join("docs").to_s)
      raise ArgumentError, "File not in docs directory"
    end

    File.read(file_path)
  end

  def docs_structure
    docs_dir = Rails.root.join("docs")
    return {} unless Dir.exist?(docs_dir)

    structure = {}
    Dir.glob("#{docs_dir}/**/*.md").each do |file|
      relative_path = Pathname.new(file).relative_path_from(docs_dir).to_s
      path_parts = relative_path.sub(/\.md$/, "").split("/")

      current = structure
      path_parts[0..-2].each do |part|
        current[part] ||= {}
        current = current[part]
      end
      current[path_parts.last] = relative_path.sub(/\.md$/, "")
    end

    structure
  end

  def build_inertia_breadcrumbs(path)
    parts = path.split("/")
    breadcrumbs = [ { name: "Docs", href: docs_path, is_link: true } ]

    current_path = ""
    parts.each_with_index do |part, index|
      current_path = current_path.empty? ? part : "#{current_path}/#{part}"

      # Check if this path exists as a file
      file_exists = File.exist?(safe_docs_path("#{current_path}.md")) ||
                   File.exist?(safe_docs_path(current_path, "index.md"))

      # Only make it a link if the file exists, or if it's the current page (last item)
      is_last = index == parts.length - 1
      if file_exists || is_last
        breadcrumbs << { name: part.titleize, href: doc_path(current_path), is_link: !is_last }
      else
        breadcrumbs << { name: part.titleize, href: nil, is_link: false }
      end
    end

    breadcrumbs
  end

  def extract_title(content)
    lines = content.lines
    title_line = lines.find { |line| line.start_with?("# ") }
    title_line&.sub(/^# /, "")&.strip
  end

  # removes .md extension from links
  class DocsRenderer < Redcarpet::Render::HTML
    def link(link, title, content)
      if link && !link.match?(/\A[a-z]+:/)
        link = link.sub(/\.md(?=[#?]|$)/, "")
      end

      attributes = "href=\"#{link}\""
      attributes += " title=\"#{title}\"" if title

      "<a #{attributes}>#{content}</a>"
    end
  end

  def render_markdown(content)
    renderer = DocsRenderer.new(
      filter_html: true,
      no_links: false,
      no_images: false,
      with_toc_data: true,
      hard_wrap: true
    )

    markdown = Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      lax_spacing: true,
      space_after_headers: true,
      superscript: false
    )

    markdown.render(content)
  end

  def render_not_found
    render inertia: "Errors/NotFound", props: {
      status_code: 404,
      title: "Page Not Found",
      message: "The documentation page you were looking for doesn't exist."
    }, status: :not_found
  end

  # Make these helper methods available to views
  helper_method :generate_doc_description, :generate_doc_keywords

  def generate_doc_description(content, title)
    # Extract first paragraph or use title
    lines = content.lines.map(&:strip).reject(&:empty?)
    first_paragraph = lines.find { |line| !line.start_with?("#") && line.length > 20 }

    if first_paragraph
      # Clean up markdown and truncate
      description = first_paragraph.gsub(/\[([^\]]*)\]\([^)]*\)/, '\1') # Remove markdown links
                                 .gsub(/[*_`]/, "") # Remove formatting
                                 .strip
      description.length > 155 ? "#{description[0..155]}..." : description
    else
      "#{title} - Complete documentation for Hackatime, the free and open source time tracker by Hack Club"
    end
  end

  def generate_doc_keywords(doc_path, title)
    base_keywords = %w[hackatime hack club open source tracker time tracking coding documentation]

    # Add path-specific keywords
    path_keywords = case doc_path
    when /getting-started/
      %w[setup installation quick start guide tutorial]
    when /api/
      %w[api rest endpoints authentication]
    when /editors/
      editor_name = doc_path.split("/").last
      [ "#{editor_name} plugin", "#{editor_name} integration", "#{editor_name} setup" ]
    else
      [ title.downcase.split.join(" ") ]
    end

    (base_keywords + path_keywords).uniq.join(", ")
  end
end
