require "base64"
require "vips"

class ProfileOgImageGenerator
  WIDTH = 1200
  HEIGHT = 630
  TEMPLATE_VERSION = 14
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
    image = Vips::Image.svgload_buffer(svg, scale: 2).resize(0.5)
    png = image.write_to_buffer(".png[compression=3,filter=0]")

    Result.new(png:, fingerprint:, filename: "profile-og-#{user.id}-v#{TEMPLATE_VERSION}.png")
  end

  def fingerprint
    @fingerprint ||= Digest::SHA256.hexdigest([
      TEMPLATE_VERSION,
      user.id,
      theme_key,
      display_name,
      username,
      user.avatar_url,
      stat_label(:all_label),
      stat_label(:week_label),
      stat_label(:streak_label),
      stat_label(:top_language_label),
      heatmap_signature,
      @stats_status
    ].join("|"))
  end

  private
    attr_reader :user, :stats, :heatmap

    def unavailable_message
      case @stats_status
      when :private then "Coding time stats are private"
      when :not_computed then "Statistics not yet computed"
      end
    end

    def svg
      ERB.new(template).result_with_hash(
        width: WIDTH,
        height: HEIGHT,
        display_name: escape(display_name),
        username: escape(username),
        avatar_data_uri: avatar_data_uri,
        initials: escape(initials),
        all_label: escape(stat_label(:all_label)),
        week_label: escape(stat_label(:week_label)),
        streak_label: escape(stat_label(:streak_label)),
        top_language_label: escape(stat_label(:top_language_label)),
        show_stats: stats.present?,
        stats_status: @stats_status,
        unavailable_message: unavailable_message,
        show_heatmap: heatmap_cells.present?,
        heatmap_cells: heatmap_cells,
        heatmap_cell: HEATMAP_CELL,
        heatmap_x: HEATMAP_X,
        palette: palette
      )
    end

    def template
      @template ||= Rails.root.join("app/views/og/profile.svg.erb").read
    end

    def display_name
      @display_name ||= user.display_name_override.presence || user.display_name
    end

    def username
      @username ||= user.username.present? ? "@#{user.username}" : "Hackatime profile"
    end

    def initials
      words = display_name.scan(/[[:alnum:]]+/).first(2)
      return "HT" if words.blank?

      words.map { |word| word[0] }.join.upcase
    end

    def stat_label(key)
      stats&.fetch(key, nil).to_s
    end

    def theme_key
      user.respond_to?(:theme) ? user.theme.to_s : User::DEFAULT_THEME
    end

    def theme_preview
      @theme_preview ||= User.theme_metadata(theme_key).fetch(:preview)
    end

    # Theme -> OG palette mapping. Mirrors the CSS variable naming used elsewhere:
    #   surface  -> theme[:dark]
    #   content  -> theme[:content]
    #   primary  -> theme[:primary]
    #   success  -> theme[:success]
    def palette
      @palette ||= begin
        surface  = theme_preview[:dark]
        content  = theme_preview[:content]
        primary  = theme_preview[:primary]
        success  = theme_preview[:success]
        darker   = theme_preview[:darker]
        darkless = theme_preview[:darkless]

        {
          bg:        darker,
          surface:   surface,
          divider:   darkless,
          primary:   primary,
          text:      content,
          muted:     hex_mix(content, surface, 0.55),
          dim:       hex_mix(content, surface, 0.35),
          # 5 heatmap intensity colors, mirroring main.css activity-cell--N.
          heatmap: [
            hex_mix(content, surface, 0.12),
            hex_mix(success, surface, 0.35),
            hex_mix(success, surface, 0.55),
            hex_mix(success, surface, 0.75),
            hex_mix(success, surface, 0.95)
          ]
        }
      end
    end

    # Linear-sRGB mix: returns `pct` of `a` mixed with `1 - pct` of `b`.
    def hex_mix(a, b, pct)
      ra, ga, ba = hex_to_rgb(a)
      rb, gb, bb = hex_to_rgb(b)
      r = (ra * pct + rb * (1 - pct)).round.clamp(0, 255)
      g = (ga * pct + gb * (1 - pct)).round.clamp(0, 255)
      bl = (ba * pct + bb * (1 - pct)).round.clamp(0, 255)
      format("#%02x%02x%02x", r, g, bl)
    end

    def hex_to_rgb(hex)
      h = hex.to_s.delete_prefix("#")
      [ h[0..1], h[2..3], h[4..5] ].map { |c| c.to_i(16) }
    end

    # Heatmap layout: HEATMAP_WEEKS columns x 7 rows ending today.
    # Each cell is keyed by ISO date string in the supplied `heatmap` hash.
    def heatmap_cells
      return @heatmap_cells if defined?(@heatmap_cells)
      return @heatmap_cells = nil if heatmap.blank?

      total_days = HEATMAP_WEEKS * 7
      today = Date.current
      start = today - (total_days - 1)
      # Align so that the rightmost column ends on the current weekday row.
      busiest = heatmap.values.max.to_i
      busiest = 1 if busiest <= 0

      cells = []
      (0...total_days).each do |i|
        date = start + i
        col = i / 7
        row = i % 7
        seconds = heatmap[date.iso8601].to_i
        level = intensity_level(seconds, busiest)
        cells << {
          x: HEATMAP_X + col * (HEATMAP_CELL + HEATMAP_GAP),
          y: HEATMAP_Y + row * (HEATMAP_CELL + HEATMAP_GAP),
          color: palette[:heatmap][level]
        }
      end
      @heatmap_cells = cells
    end

    def intensity_level(seconds, busiest)
      return 0 if seconds < 60

      ratio = seconds.to_f / busiest
      return 4 if ratio >= 0.8
      return 3 if ratio >= 0.5
      return 2 if ratio >= 0.2
      1
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

      Rails.cache.fetch("profile_og_avatar:v1:#{Digest::SHA256.hexdigest(avatar_url)}", expires_in: 1.day) do
        fetch_avatar_data_uri(avatar_url)
      end
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

    def escape(value)
      ERB::Util.html_escape(value.to_s)
    end
end
