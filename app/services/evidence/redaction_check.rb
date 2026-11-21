# Checks that a redacted frame copy is the committed frame with parts
# covered, not some other picture. The server never sees the original, but
# each block commits the frame's perceptual hash: the brightness of each cell
# of an 8x8 greyscale thumbnail, row by row from the top left, as 128 hex
# digits (desktop/macos WindowCapture.perceptualHash). Cells no redaction
# region touches must still mostly match it.
module Evidence
  module RedactionCheck
    class Invalid < StandardError; end

    GRID = 8
    MAX_REDACTED_AREA = 0.5
    MIN_CLEAR_CELLS = 16
    MAX_CLEAR_MISMATCH = 0.1
    # How far a cell may drift through re-encoding and a different scaler.
    CELL_TOLERANCE = 12
    MAX_SIDE = 2560 # the app sends frames at most 1024 pixels wide

    module_function

    # regions: [{ "x", "y", "w", "h" }] in pixels from the top left.
    def check!(image_data:, committed_phash:, regions:)
      raise Invalid, "This frame has no committed perceptual hash, so a redacted copy cannot be checked" unless committed_phash.to_s.match?(/\A\h{#{GRID * GRID * 2}}\z/)
      raise Invalid, "A redacted frame must list its redacted regions" if regions.empty?

      image = load(image_data)
      width, height = image.width, image.height
      boxes = regions.map { |region| box(region, width, height) }
      area = boxes.sum { |x, y, w, h| w * h }
      raise Invalid, "At most half of a frame can be redacted" if area > MAX_REDACTED_AREA * width * height

      clear = clear_cells(boxes, width, height)
      raise Invalid, "Too little of the frame is left to check" if clear.length < MIN_CLEAR_CELLS

      committed = [ committed_phash ].pack("H*").bytes
      uploaded = cells(image)
      mismatched = clear.count { |cell| (committed[cell] - uploaded[cell]).abs > CELL_TOLERANCE }
      raise Invalid, "The redacted copy does not match the committed frame" if mismatched > MAX_CLEAR_MISMATCH * clear.length
    end

    def perceptual_hash(image) = cells(image).pack("C*").unpack1("H*")

    # The mean brightness of each grid cell, row by row from the top left.
    def cells(image)
      grey = image.colourspace(:b_w)[0]
      (0...GRID * GRID).map do |cell|
        left, top = (cell % GRID) * image.width / GRID, (cell / GRID) * image.height / GRID
        right, bottom = (cell % GRID + 1) * image.width / GRID, (cell / GRID + 1) * image.height / GRID
        grey.crop(left, top, right - left, bottom - top).avg.round
      end
    end

    # HEIC decodes only where libvips was built with an HEVC decoder, which
    # the production image is not, so clients send redacted copies as PNG
    # or JPEG.
    LOADERS = /\AVipsForeignLoad(Png|Jpeg|Webp|Heif)Buffer\z/

    def load(data)
      require "vips"
      unless Vips.vips_foreign_find_load_buffer(data, data.bytesize).to_s.match?(LOADERS)
        raise Invalid, "Send redacted frames as PNG or JPEG"
      end

      image = Vips::Image.new_from_buffer(data, "", access: :sequential)
      raise Invalid, "Frame is not an image" if image.width < GRID || image.height < GRID
      # Checked from the header, before any pixel is decoded.
      raise Invalid, "Frame is too large" if image.width > MAX_SIDE || image.height > MAX_SIDE

      (image.has_alpha? ? image.flatten : image).copy_memory
    rescue Vips::Error
      raise Invalid, "Send redacted frames as PNG or JPEG"
    end

    def box(region, width, height)
      x, y, w, h = %w[x y w h].map { |key| Integer(region[key].to_s, exception: false) }
      unless x && y && w && h && x >= 0 && y >= 0 && w.positive? && h.positive? && x + w <= width && y + h <= height
        raise Invalid, "Redacted regions must be whole pixels inside the frame"
      end

      [ x, y, w, h ]
    end

    # Indices of grid cells that no region overlaps.
    def clear_cells(boxes, width, height)
      (0...GRID * GRID).reject do |cell|
        cx0, cy0 = (cell % GRID) * width / GRID.to_f, (cell / GRID) * height / GRID.to_f
        cx1, cy1 = cx0 + width / GRID.to_f, cy0 + height / GRID.to_f
        boxes.any? { |x, y, w, h| x < cx1 && x + w > cx0 && y < cy1 && y + h > cy0 }
      end
    end
  end
end
