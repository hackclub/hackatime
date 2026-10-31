require "base64"
require "zlib"

# Renders the Open Graph card for a page: a pastel background, brand row,
# headline, description and a decorative activity heatmap seeded by the page path.
class PageOgImageGenerator
  WIDTH = 1200
  HEIGHT = 630
  TEMPLATE_VERSION = 3
  HOST = "hackatime.hackclub.com".freeze
  HEATMAP_COLUMNS = 53
  HEATMAP_CELL = 18
  HEATMAP_STEP = 24
  HEATMAP_X = -120
  HEATMAP_Y = 430

  Result = Data.define(:png, :fingerprint)

  # Pages without a chosen `background` get a pastel derived from their path.
  def initialize(headline:, description:, path:, background: nil)
    @headline = headline.to_s.squish
    @description = description.to_s.squish
    @path = path.to_s
    @background = background || pastel_for(@path)
  end

  def call
    require "vips" # we do it here so that CI doesn't need to install vips
    # This process-wide loader only receives SVG from our ERB template.
    Vips.block("VipsForeignLoadSvgBuffer", false) if Vips.respond_to?(:block)
    png = Vips::Image.svgload_buffer(svg, scale: 2).resize(0.5).write_to_buffer(".png[compression=9]")
    Result.new(png:, fingerprint:)
  end

  def fingerprint
    @fingerprint ||= Digest::SHA256.hexdigest([ TEMPLATE_VERSION, background, headline, description, path ].join("|"))
  end

  private
    attr_reader :headline, :description, :path, :background

    def self.template
      @template ||= ERB.new(Rails.root.join("app/views/og/page.svg.erb").read)
    end

    def self.icon_data_uri
      @icon_data_uri ||= "data:image/png;base64,#{Base64.strict_encode64(Rails.root.join("public/images/new-icon-rounded.png").binread)}"
    end

    def svg
      title = headline_layout
      description_y = title[:y] + (title[:lines].size - 1) * title[:step] + 62
      self.class.template.result_with_hash(
        width: WIDTH, height: HEIGHT, palette: palette, icon_data_uri: self.class.icon_data_uri,
        title: title, description_lines: wrap(description, 74, 2), description_y: description_y,
        url: escape((HOST + path.delete_suffix("/")).truncate(56)),
        heatmap_cells: heatmap_cells, heatmap_cell: HEATMAP_CELL
      )
    end

    # One large line when it fits, otherwise up to two smaller lines.
    def headline_layout
      if headline.length <= 24
        { size: 76, step: 84, y: 252, letter_spacing: -2.5, lines: [ escape(headline) ] }
      else
        { size: 64, step: 72, y: 236, letter_spacing: -2, lines: wrap(headline, 30, 2) }
      end
    end

    def wrap(text, width, max_lines)
      lines = text.split.each_with_object([ +"" ]) do |word, acc|
        if acc.last.empty? then acc.last << word
        elsif acc.last.length + 1 + word.length <= width then acc.last << " " << word
        else acc << word.dup
        end
      end
      if lines.size > max_lines
        lines = lines.first(max_lines)
        lines[-1] = "#{lines[-1].truncate(width - 1, omission: "")}…"
      end
      lines.map { |line| escape(line.truncate(width)) }
    end

    # Dark ink and a deeper heatmap accent, both in the background's hue.
    def palette
      @palette ||= begin
        hue = hue_of(background)
        ink = hsl_hex(hue, 0.3, 0.14)
        accent = hsl_hex(hue, 0.6, 0.4)
        { bg: background, text: ink,
          muted: hex_mix(ink, background, 0.72),
          dim: hex_mix(ink, background, 0.52),
          heatmap: [ 0.07, 0.22, 0.42, 0.66, 0.92 ].map { |p| hex_mix(accent, background, p) } }
      end
    end

    def pastel_for(seed) = hsl_hex(Zlib.crc32(seed) % 360, 0.7, 0.88)

    def hsl_hex(hue, saturation, lightness)
      chroma = (1 - (2 * lightness - 1).abs) * saturation
      x = chroma * (1 - ((hue / 60.0) % 2 - 1).abs)
      rgb = [ [ chroma, x, 0 ], [ x, chroma, 0 ], [ 0, chroma, x ], [ 0, x, chroma ], [ x, 0, chroma ], [ chroma, 0, x ] ][hue.to_i / 60 % 6]
      format("#%02x%02x%02x", *rgb.map { |c| ((c + lightness - chroma / 2) * 255).round })
    end

    def hue_of(hex)
      r, g, b = hex_to_rgb(hex).map { |c| c / 255.0 }
      max, min = [ r, g, b ].minmax.reverse
      return 0 if max == min

      d = max - min
      sector = case max
      when r then ((g - b) / d) % 6
      when g then (b - r) / d + 2
      else (r - g) / d + 4
      end
      (sector * 60).round % 360
    end

    # Cells fade in from the left so the heatmap never competes with the text.
    def heatmap_cells
      rng = Random.new(Zlib.crc32(path))
      (0...HEATMAP_COLUMNS * 7).filter_map do |i|
        column, row = i.divmod(7)
        level = case rng.rand
        when ...0.35 then 0
        when ...0.6 then 1
        when ...0.8 then 2
        when ...0.93 then 3
        else 4
        end
        opacity = ((column - 18) / 25.0).clamp(0, 1).round(2)
        next if opacity.zero?

        { x: HEATMAP_X + column * HEATMAP_STEP, y: HEATMAP_Y + row * HEATMAP_STEP,
          color: palette[:heatmap][level], opacity: opacity }
      end
    end

    # Linear-sRGB mix: `pct` of `a` mixed with `1 - pct` of `b`.
    def hex_mix(a, b, pct)
      mixed = hex_to_rgb(a).zip(hex_to_rgb(b)).map { |x, y| (x * pct + y * (1 - pct)).round.clamp(0, 255) }
      format("#%02x%02x%02x", *mixed)
    end

    def hex_to_rgb(hex) = hex.to_s.delete_prefix("#").scan(/../).map { |c| c.to_i(16) }
    def escape(value) = ERB::Util.html_escape(value.to_s)
end
