require "test_helper"

# Drives Hackatime Desktop's API end to end: PKCE pairing, key enrolment,
# beacon-linked signed minute blocks, shipping with frames and code
# spot-checks, then review with the access log.
class DesktopEvidenceTest < ActionDispatch::IntegrationTest
  START = Time.utc(2026, 11, 20, 10, 0, 5)

  setup do
    @user = create(:user, :with_email, username: "orpheus")
    @key = OpenSSL::PKey::EC.generate("prime256v1")
    @salt = SecureRandom.hex(32)
  end

  teardown { travel_back }

  test "a paired device chains signed minutes and ships them, and the student sees their ship without reviewer flags" do
    token = pair_device
    enrol_key(token)

    files_v1 = { "app.rb" => "def hello\n  puts 'hi'\nend\n", ".env" => "SECRET=1\n" }
    files_v2 = { "app.rb" => "def hello\n  puts 'hi'\nend\n\ndef sync(items)\n  items.map { |item| item.save! }\nend\n", ".env" => "SECRET=1\n" }
    frames = []
    20.times do |i|
      tree = i == 0 ? files_v1 : (i == 10 || i == 19 ? files_v2 : nil)
      frame = i.even? ? encrypted_frame("minute #{i}") : nil
      frames << frame if frame
      post_minute(token, i, payload(i, tree:, frame:))
    end
    device = @user.desktop_devices.sole
    assert_equal 20, device.last_seq
    assert device.evidence_blocks.all?(&:signed), "every block should carry a verified signature"
    assert_equal 20, @user.heartbeats.where(entity: "Hackatime Desktop").count, "project minutes become heartbeats"

    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 20 }, headers: auth(token), as: :json
    assert_response :created
    ship = response.parsed_body
    assert_includes ship["spot_check_seqs"], 1
    assert_includes ship["spot_check_seqs"], 20
    assert_empty ship["spot_check_seqs"] - [ 1, 11, 20 ], "only blocks with a committed tree can be spot-checked"
    revealed = ship["revealed"].first
    assert_equal Evidence::Crypto.beacon_commitment(revealed["secret"]), revealed["commitment"]

    frames.each do |frame|
      post "/api/desktop/v1/ships/#{ship["id"]}/frames", params: frame.slice(:hash, :ciphertext, :segment_key), headers: auth(token), as: :json
      assert_response :created
    end

    post "/api/desktop/v1/ships/#{ship["id"]}/submit", headers: auth(token), as: :json, params: {
      final_files: [ { path: "app.rb", content: Base64.strict_encode64(files_v2["app.rb"]) } ],
      snapshots: ship["spot_check_seqs"].map { |seq| snapshot(seq, seq == 1 ? files_v1 : files_v2) }
    }
    assert_response :success
    result = response.parsed_body
    assert_equal "submitted", result["status"]
    assert result["credited_seconds"].positive?
    record = EvidenceShip.find(ship["id"])
    assert_operator record.credited_seconds, :<=, record.ceiling_seconds
    assert_not_includes record.flags, "snapshot_mismatch"
    assert record.spot_checks.all? { |check| check["root_ok"] && check["plausible"] }, record.spot_checks.inspect

    assert_nil result["flags"], "the desktop app never sees reviewer flags"
    assert_nil result["confidence"]

    # The student's site shows their ship and who looked at it, never flags.
    reviewer = create(:user, :admin)
    record.log_view!(viewer: reviewer, action: "frame", frame: record.evidence_frames.first)
    get "/api/v1/authenticated/desktop", headers: site_auth
    assert_response :success
    overview = response.parsed_body
    assert_equal [ "in_review" ], overview["ships"].map { |row| row["status"] }
    assert_equal "#{@user.theme}", overview.dig("user", "theme", "value")
    get "/api/v1/authenticated/desktop/ships/#{record.id}", headers: site_auth
    assert_response :success
    detail = response.parsed_body
    assert_match(/focused minutes on sync-app/, detail["reflection"])
    assert_equal [ "watched a timelapse frame" ], detail["access_log"].map { |entry| entry["what"] }
    leaked = %w[flags confidence scored_seconds ceiling_seconds stretches spot_checks summary]
    assert_empty leaked & (overview["ships"].flat_map(&:keys) + detail.keys), "reviewer-only fields leaked"
    assert_no_match(/jiggler|snapshot|flag|chain|hash/i, detail.to_json)
  end

  test "the chain rejects forks, stale beacons, bad hashes and forged signatures" do
    token = pair_device
    enrol_key(token)
    post_minute(token, 0, payload(0))

    travel_to START + 60
    beacon = beacon_for(token)
    body = payload(1).to_json
    base = { seq: 2, minute: beacon["minute"], beacon_minute: beacon["minute"], captured_at_ms: (Time.current.to_f * 1000).to_i, mono_ms: 70_000, payload: body }

    post_block(token, base.merge(seq: 2, prev_hash: "0" * 64, hash: Evidence::Crypto.chain_hash("0" * 64, beacon["value"], body)))
    assert_equal "fork", response.parsed_body.dig("error", "code")

    head = @user.desktop_devices.sole.head_hash
    post_block(token, base.merge(prev_hash: head, hash: "f" * 64))
    assert_equal "bad_hash", response.parsed_body.dig("error", "code")

    good = Evidence::Crypto.chain_hash(head, beacon["value"], body)
    forged = Base64.strict_encode64(OpenSSL::PKey::EC.generate("prime256v1").sign("SHA256", [ good ].pack("H*")))
    post_block(token, base.merge(prev_hash: head, hash: good, signature: forged))
    assert_equal "bad_signature", response.parsed_body.dig("error", "code")

    post_block(token, base.merge(prev_hash: head, hash: good, mono_ms: 1))
    assert_equal "not_monotonic", response.parsed_body.dig("error", "code")

    post_block(token, base.merge(prev_hash: head, hash: good, signature: sign(good)))
    assert_response :created
    assert_equal 2, @user.desktop_devices.sole.last_seq
  end

  test "the chain rejects AI claims that are not an object of non-negative counts" do
    token = pair_device
    [ 5, { ai_lines: -100_000 }, { prompts: 1.5 }, { in_tokens: 10**12 }, { waiting: "yes" } ].each_with_index do |ai, i|
      travel_to START + i.minutes
      beacon = beacon_for(token)
      device = @user.desktop_devices.sole
      body = payload(i).merge(ai:).to_json
      post_block(token, { seq: device.last_seq + 1, minute: beacon["minute"], beacon_minute: beacon["minute"], prev_hash: device.head_hash,
        captured_at_ms: (Time.current.to_f * 1000).to_i, mono_ms: (i + 1) * 60_000, payload: body,
        hash: Evidence::Crypto.chain_hash(device.head_hash, beacon["value"], body) })
      assert_equal "malformed", response.parsed_body.dig("error", "code"), "ai=#{ai.inspect} should be rejected"
    end
    assert_equal 0, @user.desktop_devices.sole.last_seq
    assert_empty @user.heartbeats

    post_minute(token, 6, payload(6).merge(ai: { prompts: 2, ai_lines: 0, human_lines: 4, waiting: true, accepted: 1 }))
    assert_equal 1, @user.desktop_devices.sole.last_seq
  end

  test "a draft reveals only its own device's secrets, so another device cannot pick which of its frames are required" do
    token = pair_device
    oracle_user = create(:user, :with_email, username: "oracle")
    oracle = pair_device(user: oracle_user)
    chosen = []
    12.times do |i|
      travel_to START + i.minutes
      post_minute(oracle, i, { focus: "unknown" }, user: oracle_user)
      seq = oracle_user.desktop_devices.sole.last_seq
      post "/api/desktop/v1/ships", params: { project: "x", from_seq: seq, to_seq: seq }, headers: auth(oracle), as: :json
      leaked = response.parsed_body["revealed"].sole
      assert_equal Evidence::Crypto.beacon_commitment(leaked["secret"]), leaked["commitment"]
      frame = nil
      loop do
        frame = encrypted_frame("minute #{i} #{SecureRandom.hex(4)}")
        break if Evidence::Crypto.required_frame?(leaked["secret"], frame[:hash], EvidenceShip::REQUIRED_FRAME_RATIO) == i.even?
      end
      chosen << frame[:hash] if i.even?
      post_minute(token, i, payload(i, frame:))
    end
    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 12 }, headers: auth(token), as: :json
    assert_response :created
    assert_not_equal chosen.sort, response.parsed_body["required_frames"].sort
    response.parsed_body["revealed"].each { |revealed| assert_equal Evidence::Crypto.beacon_commitment(revealed["secret"]), revealed["commitment"] }
  end

  test "after a draft reveals a beacon the device cannot chain under it, and spot-checks do not change with the draft" do
    token = pair_device
    files = { "app.rb" => "puts 1\n" }
    20.times { |i| post_minute(token, i, payload(i, tree: files.merge("n.rb" => i.to_s))) }
    choices = 4.times.map do
      post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 20 }, headers: auth(token), as: :json
      assert_response :created
      EvidenceShip.find(response.parsed_body["id"]).destroy!
      response.parsed_body.values_at("spot_check_seqs", "required_frames")
    end
    assert_equal 1, choices.uniq.length, "re-creating the draft must not re-roll the choice"

    # The last block's beacon is revealed: a block reusing it (one minute late, still online) is refused.
    beacon = @user.desktop_devices.sole.evidence_blocks.find_by!(seq: 20).evidence_beacon
    travel_to START + 20.minutes
    device = @user.desktop_devices.sole
    body = payload(20).to_json
    post_block(token, { seq: 21, minute: beacon.minute + 1, beacon_minute: beacon.minute, prev_hash: device.head_hash,
      captured_at_ms: (Time.current.to_f * 1000).to_i, mono_ms: 21 * 60_000, payload: body,
      hash: Evidence::Crypto.chain_hash(device.head_hash, beacon.value, body) })
    assert_equal "revealed_beacon", response.parsed_body.dig("error", "code")
    post_minute(token, 20, payload(20))
    assert_equal 21, @user.desktop_devices.sole.last_seq
  end

  test "of several overlapping drafts only the first submitted is credited" do
    token = pair_device
    files = { "app.rb" => "def hello\n  puts 'hi'\nend\n" }
    10.times { |i| post_minute(token, i, payload(i, tree: files)) }
    ships = [ [ 1, 10 ], [ 1, 9 ], [ 2, 10 ] ].map do |from, to|
      post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: from, to_seq: to }, headers: auth(token), as: :json
      assert_response :created
      response.parsed_body
    end
    statuses = ships.map do |ship|
      post "/api/desktop/v1/ships/#{ship["id"]}/submit", headers: auth(token), as: :json, params: {
        final_files: [ { path: "app.rb", content: Base64.strict_encode64(files["app.rb"]) } ],
        snapshots: ship["spot_check_seqs"].map { |seq| snapshot(seq, files) }
      }
      response.status
    end
    assert_equal [ 200, 422, 422 ], statuses
    assert_match(/overlaps a ship you already submitted/, response.parsed_body["error"])
    assert_equal 1, @user.evidence_ships.submitted.count
    assert_operator @user.evidence_ships.sum(:claimed_seconds), :<=, 10 * 45
  end

  test "a spot-check that discloses no shipped file is flagged, and the summary says what it proved" do
    token = pair_device
    files = { "app.rb" => "puts 1\n" }
    10.times { |i| post_minute(token, i, payload(i, tree: (files if i.zero? || i == 9))) }
    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 10 }, headers: auth(token), as: :json
    ship = response.parsed_body
    leaves_only = ship["spot_check_seqs"].map { |seq| { seq:, salt: @salt, entries: [ { leaf: Evidence::Crypto.merkle_leaf(@salt, "app.rb", files["app.rb"]) } ] } }
    post "/api/desktop/v1/ships/#{ship["id"]}/submit", headers: auth(token), as: :json, params: {
      final_files: [ { path: "other.rb", content: Base64.strict_encode64("x = 1\n" * 50) } ], snapshots: leaves_only
    }
    assert_response :success
    record = EvidenceShip.find(ship["id"])
    assert_includes record.flags, "undisclosed_snapshot"
    summary = Evidence::Summary.plain(Evidence::Summary.facts(record))
    assert_includes summary, "2 of 2 matched their committed roots; 0 disclosed shipped code that leads to the shipped repo."
    assert_includes summary, "2 disclosed no shipped file"
  end

  test "a redacted copy of a frame must be that frame with parts covered" do
    token = pair_device
    levels = Array.new(64) { |i| (i * 37 % 64) * 4 }
    original = blocky_png(levels)
    expected = format("%016x", levels.each_with_index.sum { |level, i| level >= levels.sum / 64 ? 1 << i : 0 })
    assert_equal expected, Evidence::RedactionCheck.perceptual_hash(Vips::Image.pngload_buffer(original)), "hash bits run row by row from the top left"

    frame = encrypted_frame("original", png: original).merge(phash: expected)
    post_minute(token, 0, payload(0, frame:))
    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 1 }, headers: auth(token), as: :json
    ship_id = response.parsed_body["id"]
    upload = ->(png, regions) do
      key = Base64.strict_decode64(frame[:segment_key])
      post "/api/desktop/v1/ships/#{ship_id}/frames", headers: auth(token), as: :json, params: {
        hash: frame[:hash], ciphertext: Base64.strict_encode64(Evidence::Crypto.aead_seal(key, png)), segment_key: frame[:segment_key],
        redacted: true, redactions: regions
      }
    end
    region = { x: 0, y: 0, w: 60, h: 40 }

    upload.(blocky_png(levels.map { |level| 252 - level }), [ region ])
    assert_response :unprocessable_entity, "a different picture is refused"
    upload.(Vips::Image.new_from_buffer(original, "").draw_rect(0, 0, 0, 60, 40, fill: true).write_to_buffer(".png"), [])
    assert_response :unprocessable_entity, "a redaction must list its regions"
    upload.(Vips::Image.new_from_buffer(original, "").draw_rect(0, 0, 0, 160, 60, fill: true).write_to_buffer(".png"), [ { x: 0, y: 0, w: 160, h: 60 } ])
    assert_response :unprocessable_entity, "most of the frame cannot be redacted"
    assert_empty EvidenceShip.find(ship_id).evidence_frames

    upload.("not an image at all, just bytes", [ region ])
    assert_response :unprocessable_entity
    assert_equal "Send redacted frames as PNG or JPEG", response.parsed_body["error"]

    upload.(Vips::Image.new_from_buffer(original, "").draw_rect(0, 0, 0, 60, 40, fill: true).write_to_buffer(".jpg[Q=80]"), [ region ])
    assert_response :created
    stored = EvidenceShip.find(ship_id).evidence_frames.sole
    assert stored.redacted
    assert_equal [ { "x" => "0", "y" => "0", "w" => "60", "h" => "40" } ], stored.redactions.map { |r| r.transform_values(&:to_s) }
  end

  test "only frames the server can bound in time count as on time, and claimed hardware keys earn nothing" do
    token = pair_device
    enrol_key(token)
    late = ->(i) { (START + i.minutes).to_i * 1000 + 3.minutes.in_milliseconds }
    stale = ->(i) { (START + i.minutes).to_i * 1000 - 10.minutes.in_milliseconds }
    4.times { |i| post_minute(token, i, payload(i, frame: encrypted_frame("honest #{i}"))) }
    4.times { |i| post_minute(token, 4 + i, payload(4 + i, frame: encrypted_frame("late #{i}").merge(at_ms: late.(4 + i)))) }
    4.times { |i| post_minute(token, 8 + i, payload(8 + i, frame: encrypted_frame("stale #{i}").merge(at_ms: stale.(8 + i)))) }
    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 12 }, headers: auth(token), as: :json
    stretch = Evidence::Scorer.call(ship: EvidenceShip.find(response.parsed_body["id"])).stretches.sole
    assert_equal 12, stretch.features["frames_due"]
    assert_equal 4, stretch.features["frames_on_time"], "frames claimed after their block or long before it are not on time"
    assert_equal 0, stretch.features["hardware_tier"]
    assert_equal 0.0, @user.desktop_devices.sole.confidence_bonus, "secure_enclave was only claimed"
  end

  test "a pairing code works once and only with its verifier" do
    verifier = SecureRandom.urlsafe_base64(48)
    challenge = Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false)
    post "/api/v1/authenticated/desktop/pairings", params: { code_challenge: challenge }, headers: site_auth, as: :json
    assert_response :unprocessable_entity, "pairing needs consent to timelapse capture"
    post "/api/v1/authenticated/desktop/pairings", params: { code_challenge: challenge, consent: true },
      headers: auth(create(:oauth_access_token, resource_owner_id: @user.id, scopes: "read").token), as: :json
    assert_response :forbidden, "the desktop scope is required"
    unverified = create(:oauth_access_token, application: create(:oauth_application, scopes: "profile desktop"), resource_owner_id: @user.id, scopes: "profile desktop")
    post "/api/v1/authenticated/desktop/pairings", params: { code_challenge: challenge, consent: true }, headers: auth(unverified.token), as: :json
    assert_response :forbidden, "only a verified application can pair devices"
    _pairing, code = DesktopPairing.issue!(user: @user, code_challenge: challenge, consented: true)

    post "/api/desktop/v1/pair", params: { code:, code_verifier: "wrong", platform: "macos" }, as: :json
    assert_response :unauthorized
    post "/api/desktop/v1/pair", params: { code:, code_verifier: verifier, platform: "macos" }, as: :json
    assert_response :created
    post "/api/desktop/v1/pair", params: { code:, code_verifier: verifier, platform: "macos" }, as: :json
    assert_response :unauthorized
  end

  test "mouse-only and jiggler minutes earn nothing, and a snapshot that does not match its root zeroes the ship" do
    token = pair_device
    files = { "app.rb" => "puts 1\n" }
    10.times do |i|
      body = payload(i, tree: (files if i.zero? || i == 9))
      body.merge!(keys: 0, clicks: 0, edits: 0, ai: { prompts: 0 }, moves: 300) if i.between?(1, 4)
      body.merge!(jiggler: 0.95) if i.between?(5, 6)
      post_minute(token, i, body)
    end
    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 10 }, headers: auth(token), as: :json
    ship = response.parsed_body

    honest = Evidence::Scorer.call(ship: EvidenceShip.find(ship["id"]))
    stretch = honest.stretches.sole
    assert_equal 2, stretch.reasons["jiggler"]
    assert_equal 4, stretch.reasons["mouse_only"]
    assert_equal 4 * 45, stretch.counted_seconds, "only the four real working minutes count"

    tampered = files.merge("app.rb" => "puts 2\n")
    post "/api/desktop/v1/ships/#{ship["id"]}/submit", headers: auth(token), as: :json, params: {
      final_files: [ { path: "app.rb", content: Base64.strict_encode64(files["app.rb"]) } ],
      snapshots: ship["spot_check_seqs"].map { |seq| snapshot(seq, seq == 1 ? tampered : files) }
    }
    assert_response :success
    assert_includes EvidenceShip.find(ship["id"]).flags, "snapshot_mismatch"
    assert_equal 0, response.parsed_body["credited_seconds"]
  end

  test "repeated identical frames zero out the minutes they cover" do
    token = pair_device
    stuck = encrypted_frame("same screen")
    6.times { |i| post_minute(token, i, payload(i, frame: stuck.merge(phash: "aaaa"))) }
    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 6 }, headers: auth(token), as: :json
    result = Evidence::Scorer.call(ship: EvidenceShip.find(response.parsed_body["id"]))
    assert_includes result.flags, "duplicate_frames"
    assert_equal 0, result.scored_seconds
  end

  test "AI claims are summed the same way everywhere, and a stored block without an ai object is read as no claims" do
    token = pair_device
    post_minute(token, 0, payload(0))
    post_minute(token, 1, payload(1))
    # A block stored before ai was validated, holding a number instead of an object.
    @user.desktop_devices.sole.evidence_blocks.find_by!(seq: 2).update_columns(payload: payload(1).merge(ai: 5).as_json)
    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 2 }, headers: auth(token), as: :json
    ship = response.parsed_body

    post "/api/desktop/v1/ships/#{ship["id"]}/submit", headers: auth(token), as: :json, params: { final_files: [ { path: "a.rb", content: "" } ] }
    assert_response :success
    facts = Evidence::Summary.facts(EvidenceShip.find(ship["id"]))
    assert_equal [ 1, 2, 3 ], facts.values_at(:prompts, :ai_lines, :human_lines)
    assert_match(/about 3 lines yourself and accepted about 2 from AI/, Evidence::Summary.reflection(EvidenceShip.find(ship["id"])))
  end

  private

  def auth(token) = { "Authorization" => "Bearer #{token}" }

  # The companion site's OAuth token for the student.
  def site_auth = auth(@site_token ||= desktop_token(@user))

  def desktop_token(user) = create(:oauth_access_token, application: create(:oauth_application, :desktop), resource_owner_id: user.id, scopes: "profile desktop").token

  def pair_device(user: @user)
    verifier = SecureRandom.urlsafe_base64(48)
    challenge = Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false)
    headers = user == @user ? site_auth : auth(desktop_token(user))
    post "/api/v1/authenticated/desktop/pairings", params: { code_challenge: challenge, consent: true }, headers:, as: :json
    assert_response :created
    code = response.parsed_body["code"]
    post "/api/desktop/v1/pair", params: { code:, code_verifier: verifier, name: "Orpheus's Mac", platform: "macos", app_version: "0.1.0" }, as: :json
    assert_response :created
    response.parsed_body["token"]
  end

  def enrol_key(token)
    post "/api/desktop/v1/key", params: { public_key: Base64.strict_encode64(@key.public_to_der), key_tier: "secure_enclave", hardware_id: "SERIAL-1" }, headers: auth(token), as: :json
    assert_response :success
    assert_equal "secure_enclave", response.parsed_body.dig("device", "key_tier")
  end

  def beacon_for(token)
    get "/api/desktop/v1/beacon", headers: auth(token)
    assert_response :success
    response.parsed_body
  end

  def payload(i, tree: nil, frame: nil)
    body = { focus: "project", project: "sync-app", category: "coding", active_s: 45, keys: 80, clicks: 4, moves: 30,
             injected: 0, rhythm: 0.7, jiggler: 0.05, edits: 3, commits: (i % 7).zero? ? 1 : 0, builds: 1,
             ai: { prompts: 1, in_tokens: 400, out_tokens: 900, ai_lines: 2, human_lines: 3 } }
    body[:tree] = { root: tree_root(tree) } if tree
    body[:frames] = [ { hash: frame[:hash], kind: "timelapse", phash: frame[:phash], at_ms: frame[:at_ms] }.compact ] if frame
    body
  end

  def post_minute(token, i, body, user: @user)
    travel_to START + i.minutes
    beacon = beacon_for(token)
    device = user.desktop_devices.sole
    # The timelapse frame lands on the second the beacon asked for, and the
    # block reporting it is sealed right after.
    if body[:frames]
      due = Time.iso8601(beacon["next_expected_at"])
      travel_to due
      body[:frames].each { |frame| frame[:at_ms] ||= due.to_i * 1000 }
    end
    json = body.to_json
    hash = Evidence::Crypto.chain_hash(device.head_hash, beacon["value"], json)
    block = { seq: device.last_seq + 1, minute: beacon["minute"], beacon_minute: beacon["minute"], prev_hash: device.head_hash,
              captured_at_ms: (Time.current.to_f * 1000).to_i, mono_ms: (i + 1) * 60_000, payload: json, hash: }
    block[:signature] = sign(hash) if device.public_key.present?
    post_block(token, block)
    assert_response :created
  end

  # A 160x80 PNG of 8x8 flat grey cells, row by row from the top left.
  def blocky_png(levels)
    require "vips"
    Vips::Image.new_from_array(levels.each_slice(8).to_a).cast(:uchar).zoom(20, 10).write_to_buffer(".png")
  end

  def post_block(token, block) = post("/api/desktop/v1/blocks", params: { blocks: [ block ] }, headers: auth(token), as: :json)

  def sign(hash_hex) = Base64.strict_encode64(@key.sign("SHA256", [ hash_hex ].pack("H*")))

  def tree_root(files)
    Evidence::Crypto.merkle_root(files.sort_by { |path, _| path.b }.map { |path, content| Evidence::Crypto.merkle_leaf(@salt, path, content) })
  end

  # Discloses only app.rb (a shipped file); .env goes as its leaf hash.
  def snapshot(seq, files)
    entries = files.sort_by { |path, _| path.b }.map do |path, content|
      path == "app.rb" ? { path:, content: Base64.strict_encode64(content) } : { leaf: Evidence::Crypto.merkle_leaf(@salt, path, content) }
    end
    { seq:, salt: @salt, entries: }
  end

  def encrypted_frame(text, png: nil)
    require "vips"
    png ||= Vips::Image.black(64, 32).add(40).cast(:uchar).draw_rect(255, text.sum % 50, 4, 10, 10, fill: true).write_to_buffer(".png")
    key = SecureRandom.random_bytes(32)
    ciphertext = Evidence::Crypto.aead_seal(key, png)
    { hash: Evidence::Crypto.sha256_hex(ciphertext), ciphertext: Base64.strict_encode64(ciphertext), segment_key: Base64.strict_encode64(key) }
  end
end
