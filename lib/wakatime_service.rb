require "digest"

include ApplicationHelper
include ErrorReporting

class WakatimeService
  USER_AGENT_MIDDLEWARES = %w[wakatime-ls wakatime-cli].freeze
  USER_AGENT_OS_PRODUCTS = %w[linux windows macos darwin win mac wsl].freeze
  AI_AGENT_PRODUCTS = %w[
    amp antigravity-cli antigravity-desktop antigravity-ide claude claude-code claudecode
    codex codex-cli continue cody copilot cursor gemini github-copilot
    github-copilot-cli goose kiro opencode opencode-cli pi qoder qwen-code
    qwen-code-cli roo-code windsurf
  ].freeze
  UNAMBIGUOUS_AI_AGENT_PREFIXES = %w[
    amp antigravity-cli antigravity-desktop antigravity-ide claude-code claudecode
    codex-cli copilot github-copilot github-copilot-cli opencode-cli qwen-code-cli
  ].freeze
  AI_MODEL_PRODUCTS_WITH_EDITOR_NAME_COLLISIONS = %w[claude codex gemini].freeze

  def initialize(user: nil, specific_filters: [], allow_cache: true, limit: 10, start_date: nil, end_date: nil, scope: nil, boundary_aware: false, valid_timestamps_only: false, exclude_categories: [])
    @scope = scope || Heartbeat.all
    @scope = @scope.with_valid_timestamps if valid_timestamps_only
    @scope = @scope.where.not("LOWER(category) IN (?)", exclude_categories) if exclude_categories.any?
    @exclude_categories = exclude_categories
    @user = user
    @boundary_aware = boundary_aware

    @start_date = convert_to_unix_timestamp(start_date)
    @end_date = convert_to_unix_timestamp(end_date)

    # Default to 1 year ago if no start_date provided or if no data exists
    @start_date = @start_date || @scope.minimum(:time) || 1.year.ago.to_i
    @end_date = @end_date || @scope.maximum(:time) || Time.current.to_i

    @scope = @scope.where("time >= ? AND time < ?", @start_date, @end_date)

    @limit = limit
    @limit = nil if @limit&.zero?

    @scope = @scope.where(user_id: @user.id) if @user.present?

    @specific_filters = specific_filters
    @allow_cache = allow_cache
    @raw_names = boundary_aware # test-mode parity: use raw key.presence names when boundary_aware
  end

  def generate_summary
    return cached_summary if @allow_cache

    build_summary
  end

  def cached_summary
    Rails.cache.fetch(summary_cache_key, expires_in: 1.minute) do
      build_summary
    end
  end

  def build_summary
    summary = {}

    summary[:username] = @user.display_name if @user.present?
    summary[:user_id] = @user.id.to_s if @user.present?
    summary[:is_coding_activity_visible] = true if @user.present?
    summary[:is_other_usage_visible] = true if @user.present?
    summary[:status] = "ok"

    @start_time = @start_date
    @end_time = @end_date

    summary[:start] = Time.at(@start_time).strftime("%Y-%m-%dT%H:%M:%SZ")
    summary[:end] = Time.at(@end_time).strftime("%Y-%m-%dT%H:%M:%SZ")

    summary[:range] = "all_time"
    summary[:human_readable_range] = "All Time"

    @total_seconds = if @boundary_aware
      Heartbeat.duration_seconds_boundary_aware(@scope, @start_date, @end_date, excluded_categories: @exclude_categories) || 0
    else
      @scope.duration_seconds || 0
    end
    summary[:total_seconds] = @total_seconds

    @total_days = (@end_time - @start_time) / 86400
    summary[:daily_average] = @total_days.zero? ? 0 : @total_seconds / @total_days

    summary[:human_readable_total] = ApplicationController.helpers.short_time_detailed(@total_seconds)
    summary[:human_readable_daily_average] = ApplicationController.helpers.short_time_detailed(summary[:daily_average])

    summary[:languages] = generate_summary_chunk(:language) if @specific_filters.include?(:languages)
    summary[:projects] = generate_summary_chunk(:project) if @specific_filters.include?(:projects)

    summary
  end

  def summary_cache_key
    scope_digest = Digest::SHA256.hexdigest(@scope.to_sql)
    filters = @specific_filters.map(&:to_s).sort.join(",")

    [ "wakatime_service", "summary", "v1", scope_digest, filters, @limit ].join(":")
  end

  def generate_summary_chunk(group_by)
    result = []
    @scope.group(group_by).duration_seconds.each do |key, value|
      entry = {
        name: @raw_names ? (key.presence || "Other") : transform_display_name(group_by, key),
        total_seconds: value,
        text: ApplicationController.helpers.short_time_simple(value),
        hours: value / 3600,
        minutes: (value % 3600) / 60,
        percent: (100.0 * value / @total_seconds).round(2),
        digital: ApplicationController.helpers.digital_time(value)
      }
      entry[:color] = LanguageUtils.color(key) if group_by == :language
      result << entry
    end
    result = result.sort_by { |item| -item[:total_seconds] }
    result = result.first(@limit) if @limit.present?
    result
  end

  def self.parse_user_agent(user_agent, category: nil)
    return { os: "", editor: "", err: "failed to parse user agent string" } if user_agent.blank?

    # Everything after the platform is an ordered editor/plugin chain, possibly
    # preceded by a runtime and a model token from an AI transcript parser.
    if matches = user_agent.match(/\Awakatime\/\S*\s+\(([^)]+)\)(?:\s+(.*))?\z/i)
      products = matches[2].to_s.split
      products.shift if runtime_product?(user_agent_product(products.first).downcase)
      ai_model = nil

      model_prefixed = ai_category?(category) && model_first_product_chain?(products)
      if model_prefixed
        ai_model = products.shift
      end

      return {
        os: normalize_os(matches[1], user_agent:),
        editor: extract_editor(products, skip_ai_agents: !model_prefixed),
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

  def self.model_first_product_chain?(products)
    meaningful_products = products.reject do |token|
      product = user_agent_product(token)
      product.blank? || product.start_with?("(")
    end
    return false if meaningful_products.length < 2

    first_product_original = user_agent_product(meaningful_products.first)
    first_product = first_product_original.downcase
    second_product = user_agent_product(meaningful_products.second).downcase

    # Plugin products identify editors. They are never model tokens.
    return false if plugin_product?(meaningful_products.first)

    # A normal editor chain commonly ends with its own plugin. This does not
    # need an editor allowlist, so a newly supported editor cannot accidentally
    # become a model merely because Hackatime has not heard of it yet.
    return false if meaningful_products.any? { plugin_product?(_1) && plugin_base(_1) == first_product }

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
    return false if meaningful_products.length == 2 && plugin_product?(meaningful_products.second)

    true
  end

  def self.user_agent_product(token) = token.to_s.split("/", 2).first

  def self.extract_editor(products, skip_ai_agents: false)
    skipped_ai_agent = nil
    skip_known_agents = skip_ai_agents && products.length > 2
    first_candidate = true

    products.each do |token|
      product = user_agent_product(token)
      next if product.blank? || product.start_with?("(")

      product_downcase = product.downcase
      next if product_downcase == "wakatime" || USER_AGENT_MIDDLEWARES.include?(product_downcase) || runtime_product?(product_downcase)

      if plugin_product?(product)
        candidate = plugin_base(product)
        next if USER_AGENT_OS_PRODUCTS.include?(candidate)

        return normalize_editor(candidate)
      end

      skip_agent = first_candidate || UNAMBIGUOUS_AI_AGENT_PREFIXES.include?(product_downcase)
      if skip_known_agents && skip_agent && AI_AGENT_PRODUCTS.include?(product_downcase)
        skipped_ai_agent ||= product_downcase
        first_candidate = false
        next
      end

      return normalize_editor(product_downcase)
    end

    normalize_editor(skipped_ai_agent || "")
  end

  def self.plugin_product?(token)
    product = user_agent_product(token)
    product.casecmp?("wakatime.nvim") || product.match?(/[-_](?:waka|hacka)time\z/i)
  end

  def self.plugin_base(token)
    product = user_agent_product(token)
    return "neovim" if product.casecmp?("wakatime.nvim")

    product.sub(/[-_](?:waka|hacka)time\z/i, "").downcase
  end

  def self.normalize_editor(editor)
    case editor
    when "github-copilot-cli" then "copilot-cli"
    when "ktexteditor" then "kate"
    when "vs-code" then "vscode"
    else editor
    end
  end

  def self.runtime_product?(product)
    product == "python" || product == "go" || product.match?(/\A(?:python|go)\d/)
  end

  def self.normalize_os(platform, user_agent:)
    return "wsl" if user_agent.match?(/-wsl2-/i)

    candidate = platform.to_s.sub(/\A\(/, "").split(/[\s)_-]/).first.to_s.downcase
    case candidate
    when "win", "windows" then "windows"
    when "darwin", "mac", "macos" then "macos"
    else candidate
    end
  end

  def self.parse_browser_or_legacy_user_agent(user_agent, category: nil)
    browser = if user_agent.match?(/\b(?:edg|edge)\//i)
      "edge"
    elsif user_agent.match?(/\bfirefox\//i)
      "firefox"
    elsif user_agent.match?(/\b(?:chrome|chromium)\//i)
      "chrome"
    elsif user_agent.match?(/\Ahbuilder x\//i)
      "hbuilder-x"
    end

    if browser
      os = if user_agent.match?(/windows|win_/i)
        "windows"
      elsif user_agent.match?(/mac(?:intosh|_| )|darwin/i)
        "macos"
      elsif user_agent.match?(/linux/i)
        "linux"
      else
        ""
      end
      return { os:, editor: browser, ai_model: nil, err: nil }
    end

    os = direct_user_agent_os(user_agent)
    products = user_agent.gsub(/\([^)]*\)/, " ").split.reject { direct_os_product?(_1) }
    has_parseable_product = products.any? { _1.include?("/") || plugin_product?(_1) }
    return { os: "", editor: "", err: "failed to parse user agent string" } unless has_parseable_product

    model_prefixed = ai_category?(category) && model_first_product_chain?(products)
    ai_model = model_prefixed ? products.shift : nil

    # Some integrations put an editor name containing spaces before their
    # plugin product. Splitting that name is ambiguous, while the plugin suffix
    # provides an exact and future-compatible editor identifier.
    malformed_leading_product = !ai_category?(category) && products.first.present? &&
      !products.first.include?("/") && !plugin_product?(products.first)
    editor = if products.one? && USER_AGENT_MIDDLEWARES.include?(user_agent_product(products.first).downcase)
      normalize_editor(user_agent_product(products.first).downcase)
    elsif malformed_leading_product
      plugin = products.find { plugin_product?(_1) }
      normalize_editor(plugin ? plugin_base(plugin) : "")
    else
      extract_editor(products, skip_ai_agents: ai_category?(category) && !model_prefixed)
    end

    return { os:, editor:, ai_model:, err: nil } if editor.present?

    { os: "", editor: "", err: "failed to parse user agent string" }
  end

  def self.direct_user_agent_os(user_agent)
    return "wsl" if user_agent.match?(/wsl2?/i)
    return "windows" if user_agent.match?(/windows|win_/i)
    return "macos" if user_agent.match?(/macintosh|mac[_ -]?os|darwin/i)
    return "linux" if user_agent.match?(/linux/i)

    ""
  end

  def self.direct_os_product?(token)
    token.to_s.match?(/\A(?:windows|win|linux|darwin|macos|mac)(?:[_-].*)?\z/i)
  end

  private_class_method :ai_category?, :model_first_product_chain?, :user_agent_product,
    :extract_editor, :plugin_product?, :plugin_base, :normalize_editor, :runtime_product?, :normalize_os,
    :parse_browser_or_legacy_user_agent, :direct_user_agent_os, :direct_os_product?


  def transform_display_name(group_by, key)
    value = key.presence || "Other"
    case group_by
    when :editor
      ApplicationController.helpers.display_editor_name(value)
    when :operating_system
      ApplicationController.helpers.display_os_name(value)
    when :language
      ApplicationController.helpers.display_language_name(value)
    else
      value
    end
  end

  def self.categorize_language(language)
    return nil if language.blank?

    LanguageUtils.display_name(language)
  end

  private

  def convert_to_unix_timestamp(timestamp)
    # our lord and savior stack overflow for this bit of code
    return nil if timestamp.nil?

    case timestamp
    when String
      Time.parse(timestamp).to_i
    when Time, DateTime, Date
      timestamp.to_i
    when Numeric
      timestamp.to_i
    else
      nil
    end
  rescue ArgumentError => e
    report_error(e, message: "Error converting timestamp")
    nil
  end
end
