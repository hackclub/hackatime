# Ship-time code checks. Snapshots of the working tree were committed during
# work only as salted Merkle roots; at ship the server picks a few of them
# (from its revealed secret), the user uploads those files, and each one must
#   1. hash back to the root committed in its minute, and
#   2. look like a step toward the final shipped repo, judged on tracked
#      shipped files only with winnowed k-gram fingerprints (as in MOSS).
# The final repo also sets the output ceiling on credited time.
module Evidence
  module SnapshotCheck
    MAX_FILES = 2_000
    MAX_FILE_BYTES = 512.kilobytes
    MAX_TOTAL_BYTES = 20.megabytes

    module_function

    # A snapshot is the ordered leaf list of its Merkle tree. Files that are
    # tracked in the shipped repo come with content; every other file only
    # with its leaf hash, so unshipped files are never disclosed.
    #   entries: [{ "path" => "...", "content" => base64 } | { "leaf" => hex }]
    # Returns [leaf hashes in order, { path => content } for disclosed files].
    def decode_snapshot(salt_hex, entries)
      leaves = []
      files = decode_files(Array(entries).select { |entry| entry.key?("path") })
      Array(entries).each do |entry|
        if entry.key?("path")
          leaves << Crypto.merkle_leaf(salt_hex, entry["path"].to_s, files.fetch(entry["path"].to_s))
        else
          raise ArgumentError, "Invalid leaf" unless entry["leaf"].to_s.match?(Crypto::HEX64)

          leaves << entry["leaf"].to_s
        end
      end
      [ leaves, files ]
    end

    # files: [{ "path" => "...", "content" => base64 }]
    def decode_files(files)
      files = Array(files)
      raise ArgumentError, "Too many files" if files.length > MAX_FILES

      total = 0
      files.to_h do |file|
        path = file["path"].to_s
        raise ArgumentError, "Invalid path #{path.inspect}" if path.blank? || path.start_with?("/") || path.split("/").include?("..")

        content = Base64.strict_decode64(file["content"].to_s)
        raise ArgumentError, "#{path} is too large" if content.bytesize > MAX_FILE_BYTES

        total += content.bytesize
        raise ArgumentError, "Snapshot is too large" if total > MAX_TOTAL_BYTES

        [ path, content ]
      end
    end

    # cache: { content => fingerprints }, shared across the checks of one
    # submission so each distinct file is fingerprinted once.
    def check(block:, salt_hex:, leaves:, files:, final_files:, cache: {})
      config = Config.current[:plausibility]
      root_ok = salt_hex.to_s.match?(Crypto::HEX64) && Crypto.merkle_root(leaves) == block.tree_root
      shared = files.keys & final_files.keys
      prints = ->(contents) { contents.flat_map { |content| cache[content] ||= fingerprints(content, config) }.uniq }
      final_prints = prints.(final_files.values_at(*shared))
      snapshot_prints = prints.(files.values_at(*shared))
      overlap = snapshot_prints.empty? ? 0.0 : (snapshot_prints & final_prints).length.to_f / snapshot_prints.length
      {
        "seq" => block.seq, "root_ok" => root_ok, "files" => leaves.length, "shared_files" => shared.length,
        "overlap" => overlap.round(3), "compared" => snapshot_prints.any?, "plausible" => root_ok && (snapshot_prints.empty? || overlap >= config[:min_overlap])
      }
    end

    # Winnowing (Schleimer, Wilkerson and Aiken 2003): hash every k-gram of
    # whitespace-normalised text and keep the minimum of each window.
    def fingerprints(text, config)
      normalized = text.downcase.gsub(/\s+/, "")
      k, window = config[:winnow_k], config[:winnow_window]
      return [] if normalized.length < k

      hashes = (0..normalized.length - k).map { |i| Zlib.crc32(normalized[i, k]) }
      return hashes.uniq if hashes.length <= window

      hashes.each_cons(window).map(&:min).uniq
    end

    # Time the shipped output could plausibly have taken. Lines written by AI
    # are cheap; new files and human lines cost more.
    def ceiling_seconds(first_files:, final_files:, ai_lines:, research_ratio:)
      config = Config.current[:ceiling]
      changed = final_files.sum do |path, content|
        before = first_files[path]
        next content.count("\n") + 1 if before.nil?

        (content.lines - before.lines).length
      end
      new_files = (final_files.keys - first_files.keys).length
      human_lines = [ changed - ai_lines, 0 ].max
      seconds = config[:base_seconds] + human_lines * config[:seconds_per_human_line] +
        [ ai_lines, changed ].min * config[:seconds_per_ai_line] + new_files * config[:seconds_per_new_file]
      (seconds * (1 + config[:research_allowance] * research_ratio.clamp(0, 1))).round
    end
  end
end
