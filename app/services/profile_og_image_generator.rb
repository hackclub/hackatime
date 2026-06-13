require "base64"

class ProfileOgImageGenerator
  WIDTH = 1200
  HEIGHT = 630
  TEMPLATE_VERSION = 0
  AVATAR_MAX_BYTES = 1.megabyte
  HEATMAP_WEEKS = 52
  HEATMAP_CELL = 16
  HEATMAP_GAP = 4
  HEATMAP_X = 82
  HEATMAP_Y = 270

  AVATAR_TIMEOUT = { connect: 1, read: 2, write: 1 }.freeze
  AVATAR_HOST_ALLOWLIST = [
    /\Aavatars\.githubusercontent\.com\z/,
    /\Asecure\.gravatar\.com\z/,
    /\Ai\d+\.wp\.com\z/,
    /\Aui-avatars\.com\z/,
    /\A[^.]+\.slack-edge\.com\z/
  ].freeze

  Result = Data.define(:png, :fingerprint, :filename)

  STATS_STATUSES = %i[available private not_computed].freeze
  STAT_LABEL_KEYS = %i[all_label week_label streak_label top_language_label].freeze

  def self.call(user, stats: nil, heatmap: nil, stats_status: :available)
    new(user, stats: stats, heatmap: heatmap, stats_status: stats_status).call
  end

  def initialize(user, stats: nil, heatmap: nil, stats_status: :available)
    @user = user
    @stats = stats
    @heatmap = heatmap
    @stats_status = STATS_STATUSES.include?(stats_status) ? stats_status : :available
  end

  def call
    require "vips" # we do it here so that CI doesn't need to install vips
    png = Vips::Image.svgload_buffer(svg, scale: 2).resize(0.5).write_to_buffer(".png[compression=3,filter=0]")
    Result.new(png:, fingerprint:, filename: "profile-og-#{user.id}-v#{TEMPLATE_VERSION}.png")
  end

  def fingerprint
    @fingerprint ||= Digest::SHA256.hexdigest([
      TEMPLATE_VERSION, user.id, theme_key, display_name, username, user.avatar_url,
      *STAT_LABEL_KEYS.map { |k| stat_label(k) }, heatmap_signature, @stats_status
    ].join("|"))
  end

  private
    attr_reader :user, :stats, :heatmap

    def unavailable_message
      { private: "Coding time stats are private", not_computed: "Statistics not yet computed" }[@stats_status]
    end

    def svg
      locals = {
        width: WIDTH, height: HEIGHT,
        display_name: escape(display_name), username: escape(username),
        avatar_data_uri: avatar_data_uri, initials: escape(initials),
        show_stats: stats.present?, unavailable_message: unavailable_message,
        show_heatmap_placeholder: heatmap_cells.empty? && @stats_status == :not_computed,
        heatmap_cells: heatmap_cells, heatmap_cell: HEATMAP_CELL, heatmap_x: HEATMAP_X,
        palette: palette
      }
      STAT_LABEL_KEYS.each { |k| locals[k] = escape(stat_label(k)) }
      self.class.template.result_with_hash(locals)
    end

    def self.template
      @template ||= ERB.new(Rails.root.join("app/views/og/profile.svg.erb").read)
    end

    def display_name
      @display_name ||= user.display_name
    end

    def username
      @username ||= user.username.present? ? "@#{user.username}" : "Hackatime profile"
    end

    def initials
      words = display_name.scan(/[[:alnum:]]+/).first(2)
      return "HT" if words.blank?
      words.map { |word| word[0] }.join.upcase
    end

    def stat_label(key) = stats&.fetch(key, nil).to_s
    def theme_key = user.respond_to?(:theme) ? user.theme.to_s : User::DEFAULT_THEME
    def theme_preview = @theme_preview ||= User.theme_metadata(theme_key).fetch(:preview)

    def palette
      @palette ||= begin
        t = theme_preview
        { bg: t[:darker], surface: t[:dark], divider: t[:darkless],
          primary: t[:primary], text: t[:content],
          muted: hex_mix(t[:content], t[:dark], 0.55),
          dim:   hex_mix(t[:content], t[:dark], 0.35),
          heatmap: [ hex_mix(t[:content], t[:dark], 0.12),
                     *[ 0.35, 0.55, 0.75, 0.95 ].map { |p| hex_mix(t[:success], t[:dark], p) } ] }
      end
    end

    # Linear-sRGB mix: `pct` of `a` mixed with `1 - pct` of `b`.
    def hex_mix(a, b, pct)
      mixed = hex_to_rgb(a).zip(hex_to_rgb(b)).map { |x, y| (x * pct + y * (1 - pct)).round.clamp(0, 255) }
      format("#%02x%02x%02x", *mixed)
    end

    def hex_to_rgb(hex) = hex.to_s.delete_prefix("#").scan(/../).map { |c| c.to_i(16) }
    def heatmap_cells = @heatmap_cells ||= compute_heatmap_cells

    def compute_heatmap_cells
      return [] if heatmap.blank?

      total_days = HEATMAP_WEEKS * 7
      start = Date.current - (total_days - 1)
      busiest = [ heatmap.values.max.to_i, 1 ].max
      step = HEATMAP_CELL + HEATMAP_GAP

      (0...total_days).map do |i|
        seconds = heatmap[(start + i).iso8601].to_i
        {
          x: HEATMAP_X + (i / 7) * step,
          y: HEATMAP_Y + (i % 7) * step,
          color: palette[:heatmap][intensity_level(seconds, busiest)]
        }
      end
    end

    # 0 = inactive (< 1 min), then bucketed by fraction of the busiest day
    def intensity_level(seconds, busiest)
      return 0 if seconds < 60

      case seconds.to_f / busiest
      when 0.8..  then 4
      when 0.5..  then 3
      when 0.2..  then 2
      else             1
      end
    end

    def heatmap_signature
      return "" if heatmap.blank?
      # Bucket to hour-level granularity so we don't bust cache on every heartbeat.
      Digest::SHA256.hexdigest(heatmap.sort.map { |date, secs| "#{date}:#{secs / 3600}" }.join("|"))
    end

    def avatar_data_uri
      avatar_url = user.avatar_url.to_s
      return avatar_url if avatar_url.start_with?("data:image/")
      return nil unless allowed_avatar_url?(avatar_url)

      Rails.cache.fetch("profile_og_avatar:v1:#{Digest::SHA256.hexdigest(avatar_url)}", expires_in: 1.day) { fetch_avatar_data_uri(avatar_url) }
    end

    def fetch_avatar_data_uri(avatar_url)
      response = HTTP.timeout(AVATAR_TIMEOUT).get(avatar_url)
      return nil unless response.status.success?
      body = response.body.to_s
      return nil if body.bytesize > AVATAR_MAX_BYTES

      content_type = response.headers["content-type"].to_s.split(";").first
      return nil unless content_type.start_with?("image/")
      "data:#{content_type};base64,#{Base64.strict_encode64(body)}"
    rescue HTTP::Error, URI::InvalidURIError
      nil
    end

    def allowed_avatar_url?(url)
      uri = URI.parse(url)
      return false unless uri.is_a?(URI::HTTPS)
      AVATAR_HOST_ALLOWLIST.any? { |pattern| pattern.match?(uri.host.to_s) }
    end

    def escape(value) = ERB::Util.html_escape(value.to_s)
end
