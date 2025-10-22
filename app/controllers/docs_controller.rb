class DocsController < ApplicationController
  # Docs are publicly accessible - no authentication required

  def index
    @docs = docs_structure
  end

  def show
    @doc_path = sanitize_path(params[:path] || "index")
    @breadcrumbs = build_breadcrumbs(@doc_path)

    file_path = safe_docs_path("#{@doc_path}.md")

    unless File.exist?(file_path)
      # Try with index.md in the directory
      dir_path = safe_docs_path(@doc_path, "index.md")
      if File.exist?(dir_path)
        file_path = dir_path
      else
        render_not_found and return
      end
    end

    @content = read_docs_file(file_path)
    @title = extract_title(@content) || @doc_path.humanize
    @rendered_content = render_markdown(@content)
  rescue => e
    Rails.logger.error "Error loading docs: #{e.message}"
    render_not_found
  end

  private

  def sanitize_path(path)
    # Remove any directory traversal attempts and normalize path
    return "index" if path.blank?

    # Remove leading/trailing slashes and dangerous characters
    clean_path = path.to_s.gsub(/\A\/+|\/+\z/, "").gsub(/\.\./, "")

    # Only allow alphanumeric characters, hyphens, underscores, plus signs, and forward slashes
    clean_path = clean_path.gsub(/[^a-zA-Z0-9\-_+\/]/, "")

    # Ensure we don't have empty path
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

  def build_breadcrumbs(path)
    parts = path.split("/")
    breadcrumbs = [ { name: "Docs", path: docs_path, is_link: true } ]

    current_path = ""
    parts.each_with_index do |part, index|
      current_path = current_path.empty? ? part : "#{current_path}/#{part}"

      # Check if this path exists as a file
      file_exists = File.exist?(safe_docs_path("#{current_path}.md")) ||
                   File.exist?(safe_docs_path(current_path, "index.md"))

      # Only make it a link if the file exists, or if it's the current page (last item)
      if file_exists || index == parts.length - 1
        breadcrumbs << { name: part.titleize, path: doc_path(current_path), is_link: true }
      else
        breadcrumbs << { name: part.titleize, path: nil, is_link: false }
      end
    end

    breadcrumbs
  end

  def extract_title(content)
    lines = content.lines
    title_line = lines.find { |line| line.start_with?("# ") }
    title_line&.sub(/^# /, "")&.strip
  end

  def render_markdown(content)
    renderer = Redcarpet::Render::HTML.new(
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
    render file: "#{Rails.root}/public/404.html", status: :not_found, layout: false
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
