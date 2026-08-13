# Production integrations do not follow one user-agent standard. The branches
# below are based on observed production formats and backed by regression tests.
class WakatimeUserAgentParser
  extend ErrorReporting

  USER_AGENT_MIDDLEWARES = %w[
    exec-wakatime mcp-wakatime vscode-hackatime-tracker waka-relay wakatime-ls wakatime-cli
  ].freeze
  USER_AGENT_CONNECTORS = %w[in x].freeze
  USER_AGENT_OS_PRODUCTS = %w[linux windows macos darwin win mac wsl].freeze
  GENERIC_HOST_PLUGIN_BASES = %w[macos windows].freeze
  BROWSER_PLUGIN_BASES = %w[browser chrome edge firefox opera safari].freeze
  PLUGIN_EDITOR_ALIASES = {
    "oh-my-pi-wakatime" => "pi",
    "python-wakatime" => "pycharm",
    "wakatime-zsh-plugin" => "zsh"
  }.freeze
  SHARED_PLUGIN_EDITOR_PRODUCTS = {
    "codex" => %w[codex-desktop t3code_desktop],
    "terminal" => %w[fish zsh],
    "vim" => %w[neovim],
    "vscode" => %w[
      antigravity antigravityide arduino azdata code-oss code-server codeoss cursor cursornightly
      devin kiro onivim positron qoder sqlops trae traecn vscodium windsurf
    ]
  }.freeze
  USER_AGENT_PRODUCT_ALIASES = {
    "code - oss" => "code-oss",
    "codex desktop" => "codex-desktop",
    "cyteon" => "blender",
    "hackatime-zed-unknown" => "zed",
    "hubai nitro" => "hubai-nitro",
    "ik11235" => "fish",
    "intellij idea" => "intellijidea",
    "kdevelop-wakatime-plugin1.0.0" => "kdevelop",
    "python + streamlit-wakatime" => "streamlit-wakatime",
    "python + streamlit" => "streamlit",
    "visual studio code - insiders" => "vscode",
    "visual studio code" => "vscode",
    "visualstudiocode" => "vscode",
    "vs code" => "vscode",
    "zedpreview" => "zed"
  }.freeze
  CONTINUE_HOST_PRODUCT_ALIASES = {
    "visual studio code - insiders" => "vscode",
    "visual studio code" => "vscode",
    "visualstudiocode" => "vscode",
    "vs code" => "vscode",
    "vscodium" => "vscodium",
    "intellij idea" => "intellijidea",
    "code - oss" => "code-oss"
  }.freeze
  AI_AGENT_PRODUCT_VARIANTS = {
    "claude" => %w[claude-code claudecode]
  }.freeze
  AI_USER_AGENT_PRODUCT_ALIASES = {
    "factory droid" => "droid",
    "githubcopilot" => "github-copilot",
    "oh my pi" => "pi",
    "qwen code" => "qwen-code",
    "roo code" => "roo-code",
    "visual studio code - insiders" => "vscode",
    "visual studio code" => "vscode"
  }.freeze
  AI_AGENT_PRODUCTS = %w[
    amp antigravity antigravity-cli antigravity-desktop antigravity-ide claude claude-code claudecode
    cline codex codex-cli continue cody copilot cursor gemini github-copilot
    github-copilot-cli goose kiro opencode opencode-cli opencode-desktop pi qoder qwen-code
    qwen-code-cli roo-code windsurf
  ].freeze
  AI_MODEL_PRODUCTS_WITH_EDITOR_NAME_COLLISIONS = %w[claude codex gemini].freeze
  BARE_EDITOR_PRODUCTS = %w[
    audit bearnard chrome-extension codex codex-agent codex-cli codex_agent codexagent
    custom-bash-sync customclient figma-desktop fusion360-hackatime-custom git rblx
    strudel strudel-extension synthetic-audio test-agent ue4 unrealengine vscode
  ].freeze
  STANDALONE_AI_MODEL_PRODUCTS = %w[
    claude-code-opus4.8 composer glm hermes nemotron
  ].freeze

  def self.parse(user_agent, category: nil)
    return { os: "", editor: "", err: "failed to parse user agent string" } if user_agent.blank?

    # Everything after the platform is an ordered editor/plugin chain, possibly
    # preceded by a runtime and a model token from an AI transcript parser.
    if matches = user_agent.match(/\Awakatime\/\S*\s+\(([^)]+)\)(?:\s+(.*))?\z/i)
      products = user_agent_products(matches[2], category:)
      products.shift if runtime_product?(products.first)
      ai_model = extract_ai_model!(products, category:)
      platform_editor = editor_from_platform(matches[1])
      editor = extract_editor(products)

      return {
        os: platform_editor ? direct_user_agent_os(matches[2].to_s) : normalize_os(matches[1], user_agent:),
        editor: editor.presence || platform_editor.to_s,
        ai_model:,
        err: nil
      }
    end

    parse_browser_or_legacy_user_agent(user_agent, category:)
  rescue => e
    report_error(e, message: "Error parsing user agent string")
    { os: "", editor: "", err: "failed to parse user agent string" }
  end

  def self.ai_category?(category) = category.to_s.casecmp?("ai coding")

  def self.user_agent_products(product_chain, category: nil)
    chain = product_chain.to_s.strip
      .delete_prefix("\\\"")
      .delete_prefix("\"")
      .delete_suffix("\\")
    chain = normalize_continue_host_product(chain)
    chain = normalize_product_aliases(chain, USER_AGENT_PRODUCT_ALIASES)
    chain = normalize_ai_product_aliases(chain) if ai_category?(category)
    chain.split.map { |token| token.delete_prefix("\\\"").delete_suffix("\\") }
  end

  def self.normalize_ai_product_aliases(product_chain)
    normalize_product_aliases(product_chain, AI_USER_AGENT_PRODUCT_ALIASES)
  end

  def self.normalize_product_aliases(product_chain, product_aliases)
    aliases = product_aliases.sort_by { |alias_name, _| -alias_name.length }
    aliases.each_with_object(product_chain.dup) do |(alias_name, canonical_name), normalized|
      pattern = alias_name.split.map { Regexp.escape(_1) }.join("\\s+")
      normalized.gsub!(/(?<!\S)#{pattern}(?=\/|\s|\z)/i, canonical_name)
    end
  end

  def self.normalize_continue_host_product(product_chain)
    aliases = CONTINUE_HOST_PRODUCT_ALIASES.sort_by { |alias_name, _| -alias_name.length }
    aliases.each_with_object(product_chain.dup) do |(host_name, canonical_name), normalized|
      host_pattern = host_name.split.map { Regexp.escape(_1) }.join("\\s+")
      normalized.gsub!(
        /(?<!\S)Continue\/.*?\s+#{host_pattern}(?:\s+\d[\w.-]*)?(?=\/)/i,
        canonical_name
      )
      normalized.gsub!(
        /(?<!\S)Continue\s+#{host_pattern}(?:\s+\d[\w.-]*)?(?=\/)/i,
        canonical_name
      )
    end
  end

  def self.model_first_product_chain?(products)
    meaningful_products = products.select { |token| meaningful_product?(token) }
    return false if meaningful_products.length < 2
    first_product_original = user_agent_product(meaningful_products.first)
    first_product = first_product_original.downcase
    second_product = user_agent_product(meaningful_products.second).downcase
    generic_host_after_model = plugin_product?(meaningful_products.second) &&
      generic_host_plugin?(meaningful_products.second) && likely_ai_model_product?(meaningful_products.first)
    return false if editor_first_product_chain?(meaningful_products) && !generic_host_after_model

    # Plugin products identify editors. They are never model tokens.
    return false if plugin_product?(meaningful_products.first)

    # A duplicated user agent can contain the standalone client followed by
    # the same version of its more specific agent product.
    return false if matching_later_ai_agent_version?(meaningful_products.first, meaningful_products.drop(1))
    return false if client_version_product?(meaningful_products.first)

    # A normal editor chain commonly ends with its own plugin. This does not
    # need an editor allowlist, so a newly supported editor cannot accidentally
    # become a model merely because Hackatime has not heard of it yet.
    matching_plugin_index = meaningful_products.index do |token|
      plugin_product?(token) && plugin_matches_product?(token, first_product)
    end
    if matching_plugin_index
      variants = AI_AGENT_PRODUCT_VARIANTS.fetch(first_product, [])
      distinct_agent_index = meaningful_products.each_index.drop(1).find do |index|
        token = meaningful_products[index]
        variants.include?(user_agent_product(token).downcase)
      end
      return false unless distinct_agent_index && distinct_agent_index < matching_plugin_index
    end

    # Claude, Codex and Gemini are both model families and standalone clients.
    # In an AI category, a lowercase token is a model unless its own matching
    # plugin proves that it is the editor.
    return true if AI_MODEL_PRODUCTS_WITH_EDITOR_NAME_COLLISIONS.include?(first_product) &&
      first_product_original == first_product && second_product.present?

    # AI parsers prepend their own product even when a transcript has no model.
    # Keep these out of ai_model while retaining them as a last-resort editor.
    return false if AI_AGENT_PRODUCTS.include?(first_product)

    # A two-product `editor vscode-wakatime` chain is also normal for VS Code
    # forks (Cursor, Kiro, and future editors). A model-prefixed chain has an
    # editor/parser token in addition to this fallback plugin.
    if meaningful_products.length == 2 && plugin_product?(meaningful_products.second)
      plugin_version = meaningful_products.second.to_s.split("/", 2).second
      return true if !plugin_matches_product?(meaningful_products.second, first_product) &&
        (plugin_version.to_s.casecmp?("unknown") || likely_ai_model_product?(meaningful_products.first))

      return false
    end

    true
  end

  def self.user_agent_product(token) = token.to_s.split("/", 2).first

  def self.meaningful_product?(token)
    product = user_agent_product(token)
    product.present? && !product.start_with?("(") && product.downcase != "wakatime" &&
      !USER_AGENT_MIDDLEWARES.include?(product.downcase) && !USER_AGENT_CONNECTORS.include?(product.downcase) &&
      !runtime_product?(token)
  end

  def self.matching_later_ai_agent_version?(first_token, later_tokens)
    first_product, first_version = first_token.to_s.split("/", 2)
    return false if first_product.blank? || first_version.blank?

    variants = AI_AGENT_PRODUCT_VARIANTS.fetch(first_product.downcase, [])
    later_tokens.any? do |token|
      product, version = token.to_s.split("/", 2)
      next false unless variants.include?(product.to_s.downcase)

      version == first_version
    end
  end

  def self.client_version_product?(token)
    product, version = token.to_s.split("/", 2)

    case product.to_s.downcase
    when "claude" then version.to_s.match?(/\A2\.1(?:\.|\z)/)
    when "codex" then version.to_s.match?(/\A0\./)
    when "gemini" then version.to_s.match?(/\A1\./)
    else false
    end
  end

  def self.likely_ai_model_product?(token)
    product = user_agent_product(token).downcase
    product.match?(
      /\A(?:composer|deepseek|glm|gpt|nemotron|o[1-9](?:\z|[-_.])|opus|sonnet|haiku|gemini(?:\z|[-_.])|claude(?:\z|[-_.]))/
    )
  end

  def self.editor_first_product_chain?(products)
    return false if products.length < 2

    first, second = products
    first_product = user_agent_product(first).downcase
    if plugin_product?(second)
      return false if plugin_product?(first)
      return true if generic_host_plugin?(second)

      return plugin_matches_product?(second, first_product)
    end

    return false if products.length < 3

    return false if second.include?("/") || !ai_agent_product?(second)

    plugin = products.drop(2).find { plugin_product?(_1) }
    plugin.present? && (products.length == 3 || plugin_matches_product?(plugin, first_product))
  end

  def self.ai_agent_product?(token) = AI_AGENT_PRODUCTS.include?(user_agent_product(token).downcase)

  def self.shift_first_non_metadata_product!(products)
    index = products.index { |token| meaningful_product?(token) }
    products.delete_at(index) if index
  end

  def self.extract_ai_model!(products, category:)
    return unless ai_category?(category)

    if model_first_product_chain?(products) || standalone_model_product_chain?(products)
      return shift_first_non_metadata_product!(products)
    end

    embedded_ai_model(products)
  end

  def self.standalone_model_product_chain?(products)
    meaningful_products = products.select { |token| meaningful_product?(token) }
    return false unless meaningful_products.one?

    STANDALONE_AI_MODEL_PRODUCTS.include?(user_agent_product(meaningful_products.first).downcase)
  end

  def self.embedded_ai_model(products)
    token = products.find { |product| meaningful_product?(product) }
    product, version = token.to_s.split("/", 2)
    return if version.blank? || %w[local unknown].include?(version.downcase)

    case product.to_s.downcase
    when "copilot"
      version unless semantic_version?(version) || concatenated_client_version?(version)
    when "gemini"
      version if version.match?(/gemini|gemma|flash|pro|openai-compatible|\$\$/i) || !semantic_version?(version)
    end
  end

  def self.semantic_version?(version)
    version.match?(/\Av?\d+(?:\.\d+){1,3}(?:[-+][\w.-]+)?\z/i)
  end

  def self.concatenated_client_version?(version)
    version.match?(/\Av?\d+(?:\.\d+){1,3}[A-Z][\w.-]*\/(?:local|unknown)\z/)
  end

  def self.extract_editor(products)
    meaningful_products = products.select { |token| meaningful_product?(token) }
    legacy_plugin_editor = editor_from_legacy_plugin_chain(meaningful_products)
    return legacy_plugin_editor if legacy_plugin_editor

    if meaningful_products.first.present? && plugin_product?(meaningful_products.first)
      specific_editor = editor_from_matching_product_and_plugin(meaningful_products.drop(1))
      return specific_editor if specific_editor.present?
    end

    if editor_first_product_chain?(meaningful_products)
      first_product = user_agent_product(meaningful_products.first).downcase
      second_product = meaningful_products.second
      if plugin_product?(second_product)
        plugin_editor = plugin_base(second_product)
        variants = AI_AGENT_PRODUCT_VARIANTS.fetch(first_product, [])
        return normalize_editor(plugin_editor) if variants.include?(plugin_editor)
      end

      return normalize_editor(first_product)
    end

    products.each_with_index do |token, index|
      product = user_agent_product(token)
      next if product.blank? || product.start_with?("(")

      product_downcase = product.downcase
      next if product_downcase == "wakatime" || USER_AGENT_MIDDLEWARES.include?(product_downcase) ||
        USER_AGENT_CONNECTORS.include?(product_downcase) || runtime_product?(token)
      next if decorator_product?(product_downcase) && later_editor_evidence?(products.drop(index + 1))

      if plugin_product?(product)
        candidate = plugin_base(product)
        next if USER_AGENT_OS_PRODUCTS.include?(candidate)

        return normalize_editor(candidate)
      end

      return normalize_editor(product_downcase)
    end

    ""
  end

  def self.editor_from_legacy_plugin_chain(products)
    return unless user_agent_product(products.first).to_s.casecmp?("python")

    plugin = products.find { |token| user_agent_product(token).casecmp?("python-wakatime") }
    normalize_editor(plugin_base(plugin)) if plugin
  end

  def self.editor_from_matching_product_and_plugin(products)
    products.each_index.reverse_each do |plugin_index|
      plugin = products[plugin_index]
      next unless plugin_product?(plugin)

      matching_product = products.first(plugin_index).reverse.find do |token|
        meaningful_product?(token) && plugin_matches_product?(plugin, user_agent_product(token).downcase)
      end
      return normalize_editor(user_agent_product(matching_product).downcase) if matching_product
    end

    nil
  end

  def self.decorator_product?(product)
    %w[mozilla web].include?(product) ||
      product.match?(/\A(?:v?\d+(?:[._-]\d+)*[a-z]?|[+_.\\-])\z/i)
  end

  def self.later_editor_evidence?(products)
    products.any? { |token| meaningful_product?(token) || plugin_product?(token) }
  end

  def self.plugin_product?(token)
    product = user_agent_product(token)
    PLUGIN_EDITOR_ALIASES.key?(product.downcase) || product.casecmp?("wakatime.nvim") ||
      product.match?(/[-_](?:waka|hacka)time\z/i)
  end

  def self.plugin_base(token)
    product = user_agent_product(token)
    aliased_editor = PLUGIN_EDITOR_ALIASES[product.downcase]
    return aliased_editor if aliased_editor
    return "neovim" if product.casecmp?("wakatime.nvim")

    product.sub(/[-_](?:waka|hacka)time\z/i, "").downcase
  end

  def self.plugin_matches_product?(plugin, product)
    base = plugin_base(plugin)
    variants = AI_AGENT_PRODUCT_VARIANTS.fetch(product, [])
    base == product || SHARED_PLUGIN_EDITOR_PRODUCTS.fetch(base, []).include?(product) || variants.include?(base)
  end

  def self.generic_host_plugin?(plugin) = GENERIC_HOST_PLUGIN_BASES.include?(plugin_base(plugin))

  def self.normalize_editor(editor)
    case editor
    when "claude", "claudecode" then "claude-code"
    when "godotengine", /\Agodot\d+(?:[._-]\d+)+\z/ then "godot"
    when "github-copilot-cli" then "copilot-cli"
    when "idea", "intellijideacommunityedition", "intellijideaultimateedition" then "intellijidea"
    when /\Akicadeda\d+(?:[._-]\d+)+\z/ then "kicad"
    when "ktexteditor" then "kate"
    when "robloxstudio" then "roblox-studio"
    when "visual studio code", "vs-code", "vs_code", "vscode-insiders" then "vscode"
    else editor
    end
  end

  def self.runtime_product?(token)
    token = token.to_s
    return true if token.match?(/\Anode\/v?\d/i)
    return true if token.match?(/\Apython\/v?\d{1,2}(?:\.|\z)/i)

    !token.include?("/") && token.match?(/\A(?:go|java|node|python)(?:\d|\z)/i)
  end

  def self.editor_from_platform(platform)
    case platform.to_s
    when /\Avs\s?code(?:\/|,|\z)/i then "vscode"
    when /\Atermux-wakatime\z/i then "termux"
    when /\Awebstorm\z/i then "webstorm"
    end
  end

  def self.normalize_os(platform, user_agent:)
    return "wsl" if user_agent.match?(/-wsl2-/i)
    return "android" if platform.match?(/android/i)
    return "chromeos" if platform.match?(/\Achrome\s+os\z/i)
    return "windows" if platform.match?(/\Awin(?:11-wakatime|32)\z/i)
    return "macos" if platform.match?(/\A(?:darwin|macintosh)(?:;|\z)/i)
    return "ios" if platform.match?(/\A(?:iphone|ipad)\z/i)
    return "" if platform.match?(
      /\A(?:blender(?:-|$)|c# client\z|none(?:-|$)|os_name\z|python client\z|termux-wakatime\z|vs\s?code(?:\/|,|$)|web\z|webstorm\z)/i
    )

    candidate = platform.to_s.sub(/\A\(/, "").split(/[\s)_-]/).first.to_s.downcase
    case candidate
    when "win", "windows" then "windows"
    when "darwin", "mac", "macos" then "macos"
    else candidate
    end
  end

  def self.parse_browser_or_legacy_user_agent(user_agent, category: nil)
    legacy_onshape = parse_legacy_onshape_user_agent(user_agent)
    return legacy_onshape if legacy_onshape

    legacy = parse_legacy_os_editor_user_agent(user_agent)
    return legacy if legacy

    legacy_version_editor = parse_legacy_version_editor_user_agent(user_agent)
    return legacy_version_editor if legacy_version_editor

    legacy_wakatime_editor = parse_legacy_wakatime_editor_user_agent(user_agent)
    return legacy_wakatime_editor if legacy_wakatime_editor

    browser = if user_agent.match?(/\b(?:edg|edga|edge)\//i)
      "edge"
    elsif user_agent.match?(/\b(?:opr|opera)\//i)
      "opera"
    elsif user_agent.match?(/\bfirefox\//i)
      "firefox"
    elsif user_agent.match?(/\b(?:chrome|chromium)\//i)
      "chrome"
    elsif user_agent.match?(/\Ahbuilder x\//i)
      "hbuilder-x"
    elsif user_agent.match?(/\bsafari\//i)
      "safari"
    end

    if browser
      os = if user_agent.match?(/android/i)
        "android"
      elsif user_agent.match?(/windows|win_/i)
        "windows"
      elsif user_agent.match?(/mac(?:intosh|os|_| )|darwin/i)
        "macos"
      elsif user_agent.match?(/\bcros(?:\b|[_-])|chrome\s*os/i)
        "chromeos"
      elsif user_agent.match?(/linux/i)
        "linux"
      else
        ""
      end
      products = user_agent_products(user_agent.gsub(/\([^)]*\)/, " "), category:)
      editor = editor_from_browser_plugin_chain(products) || browser
      return { os:, editor:, ai_model: nil, err: nil }
    end

    legacy_platform_product = parse_legacy_platform_product_user_agent(user_agent)
    return legacy_platform_product if legacy_platform_product

    os = direct_user_agent_os(user_agent)
    products = user_agent_products(user_agent.gsub(/\([^)]*\)/, " "), category:)
      .reject { direct_os_product?(_1) }
    meaningful_products = products.select { |token| meaningful_product?(token) }
    has_parseable_product = products.any? { _1.include?("/") || plugin_product?(_1) }
    has_bare_editor = meaningful_products.one? &&
      BARE_EDITOR_PRODUCTS.include?(user_agent_product(meaningful_products.first).downcase)
    unless has_parseable_product || has_bare_editor
      return { os:, editor: "", err: "failed to parse user agent string" }
    end

    ai_model = extract_ai_model!(products, category:)

    # Some integrations put an editor name containing spaces before their
    # plugin product. Splitting that name is ambiguous, while the plugin suffix
    # provides an exact and future-compatible editor identifier.
    malformed_leading_product = !ai_category?(category) && meaningful_products.length > 1 &&
      products.first.present? &&
      !products.first.include?("/") && !plugin_product?(products.first)
    editor = if products.one? && USER_AGENT_MIDDLEWARES.include?(user_agent_product(products.first).downcase)
      normalize_editor(user_agent_product(products.first).downcase)
    elsif malformed_leading_product
      plugin = products.find { plugin_product?(_1) }
      normalize_editor(plugin ? plugin_base(plugin) : "")
    else
      extract_editor(products)
    end

    return { os:, editor:, ai_model:, err: nil } if editor.present?

    { os:, editor: "", err: "failed to parse user agent string" }
  end

  def self.direct_user_agent_os(user_agent)
    return "wsl" if user_agent.match?(/wsl2?/i)
    return "android" if user_agent.match?(/\bandroid\b/i)
    return "chromeos" if user_agent.match?(/\bcros(?:\b|[_-])|chrome\s*os/i)
    return "windows" if user_agent.match?(/windows|win_/i)
    return "macos" if user_agent.match?(/macintosh|mac[_ -]?os|darwin/i)
    return "linux" if user_agent.match?(/linux/i)

    ""
  end

  def self.parse_legacy_onshape_user_agent(user_agent)
    return unless user_agent.match?(/\Aonshape-wakatime-plugin_(?:chrome|firefox|microsoft\s+edge|opera)\//i)

    { os: direct_user_agent_os(user_agent), editor: "onshape", ai_model: nil, err: nil }
  end

  def self.editor_from_browser_plugin_chain(products)
    products.each_index.reverse_each do |index|
      plugin = products[index]
      next unless plugin_product?(plugin)
      next if USER_AGENT_MIDDLEWARES.include?(user_agent_product(plugin).downcase)

      base = plugin_base(plugin)
      next if GENERIC_HOST_PLUGIN_BASES.include?(base)
      next if BROWSER_PLUGIN_BASES.include?(base)

      matching_product = products.first(index).reverse.find do |token|
        product = user_agent_product(token).downcase
        meaningful_product?(token) && plugin_matches_product?(plugin, product)
      end
      return normalize_editor(user_agent_product(matching_product).downcase) if matching_product

      return normalize_editor(base)
    end

    nil
  end

  def self.parse_legacy_os_editor_user_agent(user_agent)
    matches = user_agent.match(/\A(?<os>windows|linux|darwin|macos|mac)\/(?<remainder>.+)\z/i)
    return unless matches

    editor = matches[:remainder].split(/\s+\(|\s+(?=(?:windows|linux|darwin|macos|mac|python)\/)/i, 2).first
    return if editor.blank?

    {
      os: normalize_os(matches[:os], user_agent:),
      editor: normalize_editor(editor.downcase),
      ai_model: nil,
      err: nil
    }
  end

  def self.parse_legacy_version_editor_user_agent(user_agent)
    matches = user_agent.match(/\Av?\d+(?:\.\d+)+\/(?<editor>[a-z][\w.-]+)\z/i)
    return unless matches

    { os: "", editor: normalize_editor(matches[:editor].downcase), ai_model: nil, err: nil }
  end

  def self.parse_legacy_wakatime_editor_user_agent(user_agent)
    matches = user_agent.match(/\Awakatime\/(?<editor>[a-z][\w.-]+)\z/i)
    return unless matches

    editor = matches[:editor].downcase
    return if editor == "unset" || editor.match?(/\Av?\d/)

    { os: "", editor: normalize_editor(editor), ai_model: nil, err: nil }
  end

  def self.parse_legacy_platform_product_user_agent(user_agent)
    matches = user_agent.match(
      /\A(?<editor>[a-z][\w.-]*)(?:\/\S+)?\s+\((?<platform>[^)]+)\)(?:\s+.*)?\z/i
    )
    return unless matches
    return if decorator_product?(matches[:editor].downcase)

    os = direct_user_agent_os(matches[:platform])
    return if os.blank?

    { os:, editor: normalize_editor(matches[:editor].downcase), ai_model: nil, err: nil }
  end

  def self.direct_os_product?(token)
    token.to_s.match?(/\A(?:windows|win|linux|darwin|macos|mac)(?:[\/_-].*)?\z/i)
  end

  private_class_method :ai_category?, :user_agent_products, :normalize_ai_product_aliases,
    :normalize_product_aliases, :normalize_continue_host_product,
    :model_first_product_chain?, :user_agent_product, :meaningful_product?,
    :matching_later_ai_agent_version?, :client_version_product?, :likely_ai_model_product?,
    :editor_first_product_chain?, :ai_agent_product?,
    :shift_first_non_metadata_product!, :extract_ai_model!, :standalone_model_product_chain?,
    :embedded_ai_model, :semantic_version?, :concatenated_client_version?, :extract_editor,
    :plugin_product?, :plugin_base,
    :editor_from_legacy_plugin_chain, :editor_from_matching_product_and_plugin,
    :decorator_product?, :later_editor_evidence?,
    :plugin_matches_product?, :generic_host_plugin?, :normalize_editor, :runtime_product?, :normalize_os,
    :editor_from_platform,
    :parse_browser_or_legacy_user_agent, :direct_user_agent_os, :editor_from_browser_plugin_chain,
    :parse_legacy_onshape_user_agent, :parse_legacy_os_editor_user_agent,
    :parse_legacy_version_editor_user_agent, :parse_legacy_wakatime_editor_user_agent,
    :parse_legacy_platform_product_user_agent, :direct_os_product?
end
