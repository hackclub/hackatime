# Appends a device's minute blocks to its hash chain. Every field is a claim,
# so the chain only accepts a block that links to the device's current head,
# mixes in the server beacon of its minute, keeps capturedAt monotonic and
# near server time, and (when the device enrolled a key) carries a valid
# signature. Accepted project and research minutes become ordinary
# heartbeats so the rest of Hackatime sees desktop time.
module Evidence
  class BlockIngest
    class Rejected < StandardError
      attr_reader :code

      def initialize(code, message)
        @code = code
        super(message)
      end
    end

    MAX_BLOCKS = 120
    MAX_PAYLOAD_BYTES = 16_384
    CATEGORIES = %w[coding ai\ coding researching code\ reviewing manual\ testing running\ tests debugging writing\ docs designing].freeze
    INTEGER_FIELDS = %w[active_s keys clicks moves injected edits commits builds].freeze

    Result = Data.define(:accepted, :head_seq, :head_hash, :error)

    def self.call(...) = new(...).call

    def initialize(device:, blocks:, request_context: {})
      @device = device
      @blocks = blocks
      @request_context = request_context
      @config = Config.current
    end

    def call
      raise Rejected.new("too_many", "At most #{MAX_BLOCKS} blocks per request") if @blocks.length > MAX_BLOCKS

      accepted = []
      error = nil
      DesktopDevice.transaction do
        @device.lock!
        @blocks.each do |raw|
          accepted << append!(raw.to_h.with_indifferent_access)
        rescue Rejected => e
          error = { code: e.code, message: e.message, seq: raw.to_h.with_indifferent_access[:seq] }
          break
        end
        @device.update!(last_seen_at: Time.current)
      end
      record_heartbeats(accepted)
      Result.new(accepted: accepted.length, head_seq: @device.last_seq, head_hash: @device.head_hash, error:)
    end

    private

    def append!(raw)
      now_ms = (Time.current.to_f * 1000).to_i
      seq = Integer(raw[:seq], exception: false)
      minute = Integer(raw[:minute], exception: false)
      captured_at_ms = Integer(raw[:captured_at_ms], exception: false)
      mono_ms = Integer(raw[:mono_ms], exception: false)
      payload_json = raw[:payload].to_s
      reject!("malformed", "seq, minute, captured_at_ms and mono_ms are required integers") unless seq && minute && captured_at_ms && mono_ms
      reject!("out_of_order", "Expected seq #{@device.last_seq + 1}") unless seq == @device.last_seq + 1
      reject!("fork", "prev_hash does not match the chain head") unless raw[:prev_hash] == @device.head_hash
      reject!("payload_too_large", "Payload is too large") if payload_json.bytesize > MAX_PAYLOAD_BYTES

      reject!("bad_time", "captured_at_ms is outside its minute") unless captured_at_ms / 60_000 == minute
      reject!("not_monotonic", "Minutes must increase") if @device.last_minute && minute <= @device.last_minute
      reject!("not_monotonic", "mono_ms must increase") if @device.last_mono_ms && mono_ms <= @device.last_mono_ms
      reject!("future", "captured_at_ms is ahead of server time") if captured_at_ms > now_ms + @config[:clock_skew_seconds] * 1000

      offline = (now_ms - captured_at_ms) > @config[:clock_skew_seconds] * 1000
      reject!("too_old", "Offline blocks older than a day are not accepted") if offline && now_ms - captured_at_ms > @config[:offline_max_seconds] * 1000

      beacon = EvidenceBeacon.find_by(minute: raw[:beacon_minute])
      reject!("unknown_beacon", "beacon_minute is not a published beacon") unless beacon
      # The beacon proves the block was not made before that minute. An
      # online block must use the newest beacon; an offline one may lag.
      lag = minute - beacon.minute
      reject!("beacon_from_future", "Beacon is newer than the block") if lag.negative?
      offline ||= lag > 1

      expected = Crypto.chain_hash(@device.head_hash, beacon.value, payload_json)
      reject!("bad_hash", "hash does not match H(prev, beacon, payload)") unless ActiveSupport::SecurityUtils.secure_compare(expected, raw[:hash].to_s)

      signed = false
      if @device.public_key.present?
        reject!("bad_signature", "Signature does not verify with the device key") if raw[:signature].present? && !@device.valid_signature?(expected, raw[:signature])
        signed = raw[:signature].present?
      end

      payload = parse_payload(payload_json)
      block = @device.evidence_blocks.create!(
        user_id: @device.user_id, evidence_beacon: beacon, seq:, minute:, prev_hash: @device.head_hash,
        block_hash: expected, payload:, signed:, offline:, captured_at_ms:, received_at: Time.current,
        ip_address: @request_context[:ip_address], ja4_id: Ja4.resolve(@request_context[:ja4])&.id
      )
      @device.assign_attributes(last_seq: seq, head_hash: expected, last_minute: minute, last_mono_ms: mono_ms)
      block
    end

    def parse_payload(json)
      payload = JSON.parse(json)
      reject!("malformed", "payload must be a JSON object") unless payload.is_a?(Hash)
      reject!("malformed", "focus must be one of #{EvidenceBlock::FOCUS_LABELS.join(", ")}") unless EvidenceBlock::FOCUS_LABELS.include?(payload["focus"])
      INTEGER_FIELDS.each do |field|
        next if payload[field].nil?

        reject!("malformed", "#{field} must be a non-negative integer") unless payload[field].is_a?(Integer) && payload[field] >= 0
      end
      reject!("malformed", "active_s must be at most 60") if payload["active_s"].to_i > 60
      %w[rhythm jiggler].each do |field|
        next if payload[field].nil?

        reject!("malformed", "#{field} must be between 0 and 1") unless payload[field].is_a?(Numeric) && payload[field].between?(0, 1)
      end
      Array(payload["frames"]).each do |frame|
        reject!("malformed", "frames need a 64-character hex hash") unless frame.is_a?(Hash) && frame["hash"].to_s.match?(Crypto::HEX64)
      end
      if (root = payload.dig("tree", "root"))
        reject!("malformed", "tree.root must be 64-character hex") unless root.to_s.match?(Crypto::HEX64)
      end
      payload
    rescue JSON::ParserError
      reject!("malformed", "payload is not valid JSON")
    end

    def reject!(code, message) = raise(Rejected.new(code, message))

    def record_heartbeats(blocks)
      heartbeats = blocks.filter_map do |block|
        payload = block.payload
        next unless %w[project research].include?(payload["focus"]) && payload["active_s"].to_i.positive? && payload["project"].present?

        category = payload["focus"] == "research" ? "researching" : payload["category"].presence_in(CATEGORIES) || "coding"
        ai = block.ai
        {
          time: block.captured_at_ms / 1000.0, project: payload["project"].to_s.first(200), category:,
          type: "app", entity: "Hackatime Desktop", plugin: "hackatime-desktop/#{@device.app_version}",
          ai_input_tokens: ai["in_tokens"], ai_output_tokens: ai["out_tokens"], ai_line_changes: ai["ai_lines"],
          human_line_changes: ai["human_lines"], machine: @device.name
        }.compact
      end
      return if heartbeats.empty?

      HeartbeatIngest.call(user: @device.user, mode: :direct, heartbeats:, request_context: @request_context.merge(machine: @device.name))
    end
  end
end
