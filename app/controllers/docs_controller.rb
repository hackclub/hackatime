require "redcarpet"

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
    [ "Android Studio", "android-studio" ], [ "Antigravity", "antigravity" ], [ "AppCode", "appcode" ],
    [ "Aptana", "aptana" ], [ "Aseprite", "aseprite" ], [ "Arduino IDE", "arduino-ide" ], [ "Azure Data Studio", "azure-data-studio" ],
    [ "Brackets", "brackets" ], [ "C++ Builder", "c++-builder" ],
    [ "CLion", "clion" ], [ "Cloud9", "cloud9" ], [ "Coda", "coda" ],
    [ "CodeTasty", "codetasty" ], [ "Cursor", "cursor" ], [ "DataGrip", "datagrip" ],
    [ "DataSpell", "dataspell" ], [ "DBeaver", "dbeaver" ], [ "Delphi", "delphi" ],
    [ "Eclipse", "eclipse" ], [ "Emacs", "emacs" ], [ "Eric", "eric" ],
    [ "Figma", "figma" ], [ "Gedit", "gedit" ], [ "Godot", "godot" ], [ "GoLand", "goland" ],
    [ "HBuilder X", "hbuilder-x" ], [ "Helix", "helix" ],
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

  helper_method :generate_doc_description, :generate_doc_keywords

  def index
    @page_title = "Hackatime Docs - Setup Guides for 75+ Code Editors & IDEs"
    @meta_description = "Get started with Hackatime in minutes. Step-by-step setup guides for VS Code, JetBrains, vim, Neovim, Sublime Text, and 70+ more editors and IDEs."

    render inertia: "Docs/Index", props: { popular_editors: POPULAR_EDITORS, all_editors: ALL_EDITORS }
  end

  def show
    doc_path = sanitize_path(params[:path] || "index")
    return redirect_to("/api-docs", allow_other_host: false) if doc_path.start_with?("api")

    file_path = safe_docs_path("#{doc_path}.md")
    unless File.exist?(file_path)
      dir_path = safe_docs_path(doc_path, "index.md")
      return render_not_found unless File.exist?(dir_path)
      file_path = dir_path
    end

    content = read_docs_file(file_path)
    respond_to do |format|
      format.html do
        title = extract_title(content) || doc_path.humanize
        render inertia: "Docs/Show", props: {
          doc_path: doc_path, title: title,
          rendered_content: render_markdown(content),
          breadcrumbs: build_inertia_breadcrumbs(doc_path),
          edit_url: "https://github.com/hackclub/hackatime/edit/main/docs/#{doc_path}.md",
          meta: { description: generate_doc_description(content, title),
                  keywords: generate_doc_keywords(doc_path, title) }
        }
      end
      format.md { render plain: content, content_type: "text/markdown" }
    end
  rescue => e
    report_error(e, message: "Error loading docs")
    render_not_found
  end

  private

  def sanitize_path(path)
    return "index" if path.blank?
    clean = path.to_s.split("/").reject(&:empty?).join("/").gsub("..", "").gsub(/[^a-zA-Z0-9\-_+\/]/, "")
    clean.presence || "index"
  end

  def safe_docs_path(*parts)
    docs_root = Rails.root.join("docs")
    full_path = docs_root.join(*parts)
    raise ArgumentError, "Path traversal attempted" unless full_path.to_s.start_with?(docs_root.to_s)
    full_path
  end

  def read_docs_file(file_path)
    raise ArgumentError, "File not in docs directory" unless file_path.to_s.start_with?(Rails.root.join("docs").to_s)
    File.read(file_path)
  end

  def build_inertia_breadcrumbs(path)
    parts = path.split("/")
    breadcrumbs = [ { name: "Docs", href: docs_path, is_link: true } ]

    current_path = ""
    parts.each_with_index do |part, index|
      current_path = current_path.empty? ? part : "#{current_path}/#{part}"
      file_exists = File.exist?(safe_docs_path("#{current_path}.md")) || File.exist?(safe_docs_path(current_path, "index.md"))
      is_last = index == parts.length - 1
      breadcrumbs << { name: part.titleize,
        href: (file_exists || is_last) ? doc_path(current_path) : nil,
        is_link: (file_exists || is_last) && !is_last }
    end
    breadcrumbs
  end

  def extract_title(content) = content.lines.find { |line| line.start_with?("# ") }&.sub(/^# /, "")&.strip

  # Removes .md extension from internal links so doc cross-links resolve via the router.
  class DocsRenderer < Redcarpet::Render::HTML
    def link(link, title, content)
      link = link.sub(/\.md(?=[#?]|$)/, "") if link && !link.match?(/\A[a-z]+:/)
      attributes = +%(href="#{link}")
      attributes << %( title="#{title}") if title
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
    Redcarpet::Markdown.new(
      renderer,
      autolink: true,
      tables: true,
      fenced_code_blocks: true,
      strikethrough: true,
      lax_spacing: true,
      space_after_headers: true,
      superscript: false
    ).render(content)
  end

  def render_not_found
    render inertia: "Errors/NotFound", props: {
      status_code: 404,
      title: "Page Not Found",
      message: "The documentation page you were looking for doesn't exist."
    }, status: :not_found
  end

  def generate_doc_description(content, title)
    lines = content.lines.map(&:strip).reject(&:empty?)
    first_paragraph = lines.find { |line| !line.start_with?("#") && line.length > 20 }
    return "#{title} - Complete documentation for Hackatime, the free and open source time tracker by Hack Club" unless first_paragraph

    description = first_paragraph.gsub(/\[([^\]]*)\]\([^)]*\)/, '\1').gsub(/[*_`]/, "").strip
    description.length > 155 ? "#{description[0..155]}..." : description
  end

  def generate_doc_keywords(doc_path, title)
    base = %w[hackatime hack club open source tracker time tracking coding documentation]
    extra = case doc_path
    when /getting-started/ then %w[setup installation quick start guide tutorial]
    when /api/ then %w[api rest endpoints authentication]
    when /editors/
      name = doc_path.split("/").last
      [ "#{name} plugin", "#{name} integration", "#{name} setup" ]
    else [ title.downcase.split.join(" ") ]
    end
    (base + extra).uniq.join(", ")
  end
end
