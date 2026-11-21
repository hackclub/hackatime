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
    expected = levels.pack("C*").unpack1("H*")
    assert_equal expected, Evidence::RedactionCheck.perceptual_hash(Vips::Image.pngload_buffer(original)), "cells run row by row from the top left"

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
    # Black boxes darken the whole picture; the cells left clear still match.
    upload.(Vips::Image.new_from_buffer(original, "").draw_rect(0, 0, 0, 160, 30, fill: true).write_to_buffer(".jpg[Q=80]"), [ { x: 0, y: 0, w: 160, h: 30 } ])
    assert_response :created
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

  test "pairing the same Mac again replaces the old pairing, but another account cannot take it" do
    first = pair_device
    enrol_key(first)
    second = pair_device
    enrol_key(second)
    assert_nil DesktopDevice.authenticate(first), "the old pairing of this Mac is revoked"
    assert_equal 1, @user.desktop_devices.active.count

    other = create(:user, :with_email, username: "other")
    post "/api/desktop/v1/key", params: { public_key: Base64.strict_encode64(@key.public_to_der), hardware_id: "SERIAL-1" },
      headers: auth(pair_device(user: other)), as: :json
    assert_response :conflict
    assert DesktopDevice.authenticate(second), "another account cannot unpair this Mac"
  end

  test "unpairing and pairing again does not use up the monthly device allowance, but new machines do" do
    4.times do
      token = pair_device
      enrol_key(token)
      delete "/api/desktop/v1/me", headers: auth(token)
      assert_response :no_content
    end
    enrol_key(pair_device) # the same Mac, a fifth time

    %w[SERIAL-2 SERIAL-3].each do |serial|
      post "/api/desktop/v1/key", params: { public_key: Base64.strict_encode64(OpenSSL::PKey::EC.generate("prime256v1").public_to_der), hardware_id: serial },
        headers: auth(pair_device), as: :json
      assert_response :success
    end
    verifier = SecureRandom.urlsafe_base64(48)
    _pairing, code = DesktopPairing.issue!(user: @user, code_challenge: Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false), consented: true)
    post "/api/desktop/v1/pair", params: { code:, code_verifier: verifier, platform: "macos" }, as: :json
    assert_response :unprocessable_entity
    assert_equal "Too many new devices this month", response.parsed_body["error"]
  end

  test "a ship credits only minutes on its own project, and a switch to another project is not a grace minute" do
    token = pair_device
    projects = %w[sync-app other-app sync-app other-app Sync-App sync-app]
    projects.each_with_index { |project, i| post_minute(token, i, payload(i).merge(project:)) }
    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 6 }, headers: auth(token), as: :json
    result = Evidence::Scorer.call(ship: EvidenceShip.find(response.parsed_body["id"]))
    assert_equal 4 * 45, result.claimed_seconds
    assert_equal 4 * 45, result.stretches.sum(&:counted_seconds)
    assert_equal 2, result.stretches.flat_map { |stretch| [ stretch.reasons["other_project"] ] }.compact.sum
  end

  test "minutes without input counts are unknown input, not idle, and earn no human-input confidence" do
    token = pair_device
    unknown = ->(i) { payload(i).except(:keys, :clicks, :moves, :injected, :rhythm, :jiggler).merge(edits: 0, ai: { prompts: 0 }) }
    5.times { |i| post_minute(token, i, unknown.(i).merge(edits: i == 4 ? 2 : 0)) }
    post_minute(token, 5, payload(5).merge(keys: 0, clicks: 0, edits: 0, ai: { prompts: 0 }, moves: 0))
    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 6 }, headers: auth(token), as: :json
    result = Evidence::Scorer.call(ship: EvidenceShip.find(response.parsed_body["id"]))
    stretch = result.stretches.sole
    assert_equal 5 * 45, result.claimed_seconds, "only the minute that reported zero input is idle"
    assert_equal({ "idle" => 1 }, stretch.reasons)
    assert_in_delta 1 / 6.0, stretch.features["input_known_ratio"]

    weights = Evidence::Config.current[:weights]
    without_human_input = weights[:streams_agree] + weights[:follow_up] + weights[:build_changed]
    assert_in_delta without_human_input + weights[:human_input] / 6.0, stretch.confidence, 0.001
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
    # Steady editing: new frames whose coarse perceptual hash stays the same.
    6.times { |i| post_minute(token, 6 + i, payload(6 + i, frame: encrypted_frame("edit #{i}").merge(phash: "aaaa"))) }
    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 1, to_seq: 12 }, headers: auth(token), as: :json
    result = Evidence::Scorer.call(ship: EvidenceShip.find(response.parsed_body["id"]))
    assert_includes result.flags, "duplicate_frames"
    assert_equal 6, result.stretches.sum { |stretch| stretch.features["duplicate_frames"] }
    assert_equal 6 * 45, result.claimed_seconds, "only the minutes after the frozen run count"
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

  test "minutes removed from a ship earn nothing, and the kept minutes earn what they did before" do
    token = pair_device
    # Seq 5 is a look at something unrelated and seq 6 is research; the rest is project work.
    14.times { |i| post_minute(token, i, payload(i).merge(focus: { 4 => "unrelated", 5 => "research" }.fetch(i, "project"))) }

    whole = open_ship(token, 1, 14)
    assert_equal [], whole["excluded_ranges"]
    before = Evidence::Scorer.call(ship: EvidenceShip.find(whole["id"]))
    assert_equal 14 * 45, before.claimed_seconds
    assert_equal 13 * 45 + 60, before.stretches.sole.counted_seconds, "the unrelated minute is a short switch away and counts in full"
    assert_no_match(/removed/, Evidence::Summary.plain(Evidence::Summary.facts(EvidenceShip.find(whole["id"]))))

    # Sent out of order, with two ranges that touch: seq 5..6 and 10..12 are removed.
    edited = open_ship(token, 1, 14, [ { from_seq: 11, to_seq: 12 }, { from_seq: 5, to_seq: 6 }, { from_seq: 10, to_seq: 10 } ])
    assert_equal whole["id"], edited["id"], "opening the same range again updates the draft"
    assert_equal [ [ 5, 6 ], [ 10, 12 ] ], edited["excluded_ranges"]
    after = Evidence::Scorer.call(ship: EvidenceShip.find(edited["id"]))
    assert_equal 9 * 45, after.claimed_seconds
    # Two removed minutes are no longer than the grace period, so the stretch
    # runs on across them; three end it.
    assert_equal [ [ 1, 9 ], [ 13, 14 ] ], after.stretches.map { |stretch| [ stretch.from_seq, stretch.to_seq ] }
    assert_equal [ 7 * 45, 2 * 45 ], after.stretches.map(&:counted_seconds), "a kept minute earns its 45 seconds and a removed one is never a grace minute"
    stretch = after.stretches.first
    assert_equal({ "removed" => 2 }, stretch.reasons)
    assert_equal [ 9.0, 7, 0.0 ], stretch.features.values_at("minutes", "frames_due", "unrelated_ratio"), "removed minutes owe no frame"
    assert_in_delta 1 / 9.0, stretch.features["research_ratio"], 0.0001, "the stretch still describes what the chain recorded"

    post "/api/desktop/v1/ships/#{edited["id"]}/submit", headers: auth(token), as: :json,
      params: { final_files: [ { path: "a.rb", content: Base64.strict_encode64("x = 1\n" * 30) } ] }
    assert_response :success
    assert_equal 9 * 45, response.parsed_body["claimed_seconds"]
    record = EvidenceShip.find(edited["id"])
    # One new file of 31 lines; the nine kept minutes claim 18 AI lines, which leaves 13 human
    # lines, and none of them is research: 1800 + 13 * 150 + 18 * 20 + 300.
    assert_equal 4410, record.ceiling_seconds
    assert_empty record.flags & %w[removed_checks unshipped_gaps]
    facts = Evidence::Summary.facts(record)
    assert_equal [ 9, 5, 0 ], facts.values_at(:minutes, :removed_minutes, :removed_checks)
    assert_equal [ 9, 18, 27, 0, 0 ], facts.values_at(:prompts, :ai_lines, :human_lines, :research_minutes, :unrelated_minutes)
    plain = Evidence::Summary.plain(facts)
    assert_includes plain, "9 chained minutes on sync-app"
    assert_includes plain, "The user removed 5 minutes of the range before shipping"
    assert_no_match(/already asked for/, plain)
    assert_match(/You spent 9 focused minutes on sync-app/, Evidence::Summary.reflection(record))
  end

  test "required frames, spot-checks and revealed secrets come only from the minutes a ship keeps" do
    token = pair_device
    device = @user.desktop_devices.sole
    frames = {}
    12.times do |i|
      seq = i + 1
      # Seq 6 will be removed and seq 9 kept. Both get a frame their own
      # secret makes required, and seq 6 a tree its secret spot-checks.
      frames[seq] = [ 6, 9 ].include?(seq) ? frame_with_requirement(i, true) : encrypted_frame("minute #{i}")
      tree = { "app.rb" => "puts #{i}\n" }
      tree["pad.rb"] = SecureRandom.hex(4) until seq != 6 || Evidence::Crypto.spot_check?(secret_for_minute(i), tree_root(tree), EvidenceShip::SPOT_CHECK_RATIO)
      post_minute(token, i, payload(i, tree:, frame: frames[seq]))
    end
    removed = [ 1, 2, 6, 7, 12 ]
    kept = (1..12).to_a - removed

    ship = open_ship(token, 1, 12, [ { from_seq: 1, to_seq: 2 }, { from_seq: 6, to_seq: 7 }, { from_seq: 12, to_seq: 12 } ])
    assert_equal [ [ 1, 2 ], [ 6, 7 ], [ 12, 12 ] ], ship["excluded_ranges"]

    required = kept.select { |seq| Evidence::Crypto.required_frame?(secret_for_minute(seq - 1), frames[seq][:hash], EvidenceShip::REQUIRED_FRAME_RATIO) }
    assert_includes required, 9
    assert_equal frames.values_at(*required).pluck(:hash).sort, ship["required_frames"].sort
    assert_not_includes ship["required_frames"], frames[6][:hash], "a removed minute's frame is never asked for"
    assert_equal [ 3, 11 ], ship["spot_check_seqs"].values_at(0, -1), "the first and last kept snapshots are always checked"
    assert_empty ship["spot_check_seqs"] - kept, "a removed minute's snapshot is never checked"

    beacon_minute = ->(seq) { (START + (seq - 1).minutes).to_i / 60 }
    assert_equal kept.map(&beacon_minute), ship["revealed"].pluck("minute").sort, "the secrets of removed minutes stay secret"
    ship["revealed"].each { |revealed| assert_equal Evidence::Crypto.beacon_commitment(revealed["secret"]), revealed["commitment"] }
    assert_equal kept, device.evidence_blocks.where.not(revealed_at: nil).order(:seq).pluck(:seq)
    assert_equal beacon_minute.(11), device.reload.revealed_through_minute, "the removed last minute's beacon is not closed"
  end

  test "a frame can be uploaded only when a minute the ship keeps commits it" do
    token = pair_device
    first, still, gone = encrypted_frame("first"), encrypted_frame("an unchanged screen"), encrypted_frame("gone")
    # Seq 2 and 3 repeat one hash, as the app does while the screen does not change.
    [ first, still, still, gone ].each_with_index { |frame, i| post_minute(token, i, payload(i, frame:)) }
    ship = open_ship(token, 1, 4, [ { from_seq: 2, to_seq: 2 }, { from_seq: 4, to_seq: 4 } ])

    upload_frame(token, ship, gone)
    assert_response :unprocessable_entity
    assert_equal "That minute was removed from this ship", response.parsed_body["error"]
    upload_frame(token, ship, encrypted_frame("never committed"))
    assert_response :unprocessable_entity
    assert_equal "Frame hash is not committed in this range", response.parsed_body["error"]
    upload_frame(token, ship, first)
    assert_response :created
    upload_frame(token, ship, still)
    assert_response :created, "the removed seq 2 commits this hash, but so does the kept seq 3"
    assert_equal({ first[:hash] => 1, still[:hash] => 3 }, EvidenceShip.find(ship["id"]).evidence_frames.pluck(:frame_hash, :seq).to_h)
  end

  test "a ship refuses removed ranges that are malformed, outside it or leave nothing" do
    token = pair_device
    6.times { |i| post_minute(token, i, payload(i)) }
    draft = open_ship(token, 2, 5, [ { from_seq: 3, to_seq: 3 } ])
    malformed = "Each excluded range needs an integer from_seq and to_seq, with from_seq not after to_seq"
    outside = "Excluded ranges must lie inside the ship's range"
    nothing_left = "A ship must keep at least one minute"
    [
      [ [ { from_seq: 1, to_seq: 2 } ], outside ],
      [ [ { from_seq: 5, to_seq: 6 } ], outside ],
      [ [ { from_seq: 4, to_seq: 3 } ], malformed ],
      [ [ { from_seq: "3", to_seq: 3 } ], malformed ],
      [ [ { from_seq: 3.5, to_seq: 4 } ], malformed ],
      [ [ { from_seq: 3 } ], malformed ],
      [ [ 3 ], malformed ],
      [ [ { from_seq: 2, to_seq: 5 } ], nothing_left ],
      [ [ { from_seq: 4, to_seq: 5 }, { from_seq: 2, to_seq: 3 } ], nothing_left ]
    ].each do |excluded, error|
      post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq: 2, to_seq: 5, excluded: }, headers: auth(token), as: :json
      assert_response :unprocessable_entity, "excluded=#{excluded.inspect} should be refused"
      assert_equal error, response.parsed_body["error"]
    end
    assert_equal [ [ 3, 3 ] ], EvidenceShip.sole.excluded_ranges, "a refused request leaves the draft as it was"
    assert_equal draft["id"], EvidenceShip.sole.id

    # 201 separate ranges need a longer chain than a test can post a minute at a
    # time, so the limit is checked on a ship the device's head is set to cover.
    device = @user.desktop_devices.sole
    device.update_columns(last_seq: 500)
    every_other = ->(count) { Array.new(count) { |n| [ 2 * n + 1, 2 * n + 1 ] } }
    long = device.evidence_ships.new(user: @user, project: "sync-app", from_seq: 1, to_seq: 500, excluded_ranges: every_other.(201))
    assert_not long.valid?
    assert_equal [ "A ship can have at most 200 excluded ranges" ], long.errors.full_messages
    long.excluded_ranges = every_other.(201) + [ [ 2, 2 ] ]
    assert_equal [ 1, 3 ], long.excluded_ranges.first, "ranges that touch are merged before they are counted"
    assert long.valid?, long.errors.full_messages.to_sentence
  end

  test "opening a draft again with a minute removed deletes the frame already uploaded for it" do
    token = pair_device
    first, still, gone = encrypted_frame("first"), encrypted_frame("an unchanged screen"), encrypted_frame("gone")
    [ first, still, still, gone ].each_with_index { |frame, i| post_minute(token, i, payload(i, frame:)) }
    ship = open_ship(token, 1, 4)
    [ first, still, gone ].each do |frame|
      upload_frame(token, ship, frame)
      assert_response :created
    end
    uploaded = -> { EvidenceShip.find(ship["id"]).evidence_frames.pluck(:frame_hash, :seq).to_h }
    assert_equal({ first[:hash] => 1, still[:hash] => 2, gone[:hash] => 4 }, uploaded.call)

    edited = open_ship(token, 1, 4, [ { from_seq: 2, to_seq: 2 }, { from_seq: 4, to_seq: 4 } ])
    assert_equal ship["id"], edited["id"]
    assert_equal({ first[:hash] => 1, still[:hash] => 3 }, uploaded.call, "only the frame no kept minute commits is deleted; the repeated one moves to the kept minute")
    assert_empty edited["missing_required_frames"]
    upload_frame(token, ship, gone)
    assert_response :unprocessable_entity
  end

  test "removing a minute after a draft asked for its frame is flagged, and removing it before any draft is not" do
    token = pair_device
    # Seq 4 and seq 12 each have a frame their secret makes required; no other frame is.
    frames = 16.times.map { |i| frame_with_requirement(i, [ 3, 11 ].include?(i)) }
    frames.each_with_index { |frame, i| post_minute(token, i, payload(i, frame:)) }
    dodged = -> { EvidenceShip.find(response.parsed_body["id"]).removed_checks }
    submit = lambda do |ship|
      post "/api/desktop/v1/ships/#{ship["id"]}/submit", headers: auth(token), as: :json, params: { final_files: [ { path: "a.rb", content: "" } ] }
      assert_response :success
      EvidenceShip.find(ship["id"])
    end

    # Seq 12 is removed before any draft revealed its secret, twice over.
    2.times do
      early = open_ship(token, 9, 16, [ { from_seq: 12, to_seq: 12 } ])
      assert_empty early["required_frames"]
      assert_equal 0, dodged.call
    end
    early = submit.(response.parsed_body)
    assert_not_includes early.flags, "removed_checks"
    facts = Evidence::Summary.facts(early)
    assert_equal [ 7, 1, 0 ], facts.values_at(:minutes, :removed_minutes, :removed_checks)
    assert_includes Evidence::Summary.plain(facts), "The user removed 1 minute of the range before shipping"
    assert_no_match(/already asked for/, Evidence::Summary.plain(facts))

    # The first draft over seq 1..8 asks for seq 4's frame; the second removes that minute.
    asked = open_ship(token, 1, 8)
    assert_equal [ frames[3][:hash] ], asked["required_frames"]
    assert_equal 0, dodged.call
    late = open_ship(token, 1, 8, [ { from_seq: 4, to_seq: 4 } ])
    assert_empty late["required_frames"]
    assert_equal 1, dodged.call
    assert_equal [ frames[3][:hash] ], open_ship(token, 1, 8)["required_frames"], "putting the minute back asks for its frame again"
    assert_equal 0, dodged.call
    late = submit.(open_ship(token, 1, 8, [ { from_seq: 4, to_seq: 4 } ]))
    assert_includes late.flags, "removed_checks"
    facts = Evidence::Summary.facts(late)
    assert_equal [ 7, 1, 1 ], facts.values_at(:minutes, :removed_minutes, :removed_checks)
    assert_includes Evidence::Summary.plain(facts), "That took out 1 check the server had already asked for (required frames or code snapshots)."
  end

  test "removing a minute after a draft said it would check its code snapshot is flagged, and removing it in the first open is not" do
    token = pair_device
    # Three ranges of six minutes, each with three snapshots: one at its start,
    # one in the middle that its own secret picks for a spot-check, and one
    # near its end that no secret picks. No minute has a frame.
    picked = [ 3, 9, 15 ]
    trees = [ 1, 3, 5, 7, 9, 12, 13, 15, 18 ].index_with { |seq| tree_with_spot_check(seq - 1, picked.include?(seq)) }
    18.times { |i| post_minute(token, i, payload(i, tree: trees[i + 1])) }
    dodged = -> { EvidenceShip.find(response.parsed_body["id"]).removed_checks }
    removing = ->(*seqs) { seqs.map { |seq| { from_seq: seq, to_seq: seq } } }
    submit = lambda do |ship|
      post "/api/desktop/v1/ships/#{ship["id"]}/submit", headers: auth(token), as: :json, params: {
        final_files: [ { path: "app.rb", content: Base64.strict_encode64("puts 1\n") } ],
        snapshots: ship["spot_check_seqs"].map { |seq| snapshot(seq, trees[seq]) }
      }
      assert_response :success
      EvidenceShip.find(ship["id"])
    end

    # Seq 7..12: the first snapshot and the one the secret picks are removed in the very first open, twice over.
    2.times do
      assert_equal [ 12 ], open_ship(token, 7, 12, removing.(7, 9))["spot_check_seqs"]
      assert_equal 0, dodged.call
    end
    early = submit.(response.parsed_body)
    assert_not_includes early.flags, "removed_checks"
    assert_equal [ 4, 2, 0 ], Evidence::Summary.facts(early).values_at(:minutes, :removed_minutes, :removed_checks)
    assert_no_match(/already asked for/, Evidence::Summary.plain(Evidence::Summary.facts(early)))

    # Seq 1..6: the first draft says it will check all three snapshots.
    assert_equal [ 1, 3, 5 ], open_ship(token, 1, 6)["spot_check_seqs"]
    assert_equal 0, dodged.call
    2.times do
      assert_equal [ 3, 5 ], open_ship(token, 1, 6, removing.(1))["spot_check_seqs"]
      assert_equal 1, dodged.call, "the first snapshot was asked for, and stays dodged however often the draft is opened"
    end
    assert_equal [ 5 ], open_ship(token, 1, 6, removing.(1, 2, 3))["spot_check_seqs"]
    assert_equal 2, dodged.call, "seq 2 has no snapshot and dodges nothing"
    assert_equal [ 1, 3, 5 ], open_ship(token, 1, 6)["spot_check_seqs"]
    assert_equal 0, dodged.call, "putting the minutes back asks for their snapshots again"
    # Removing until no kept minute has a snapshot at all.
    assert_empty open_ship(token, 1, 6, [ { from_seq: 1, to_seq: 5 } ])["spot_check_seqs"]
    assert_equal 3, dodged.call
    late = submit.(response.parsed_body)
    assert_includes late.flags, "removed_checks"
    facts = Evidence::Summary.facts(late)
    assert_equal [ 1, 5, 3 ], facts.values_at(:minutes, :removed_minutes, :removed_checks)
    assert_includes Evidence::Summary.plain(facts), "That took out 3 checks the server had already asked for (required frames or code snapshots)."

    # Seq 13..18: another draft reveals seq 15's secret, which picks its snapshot. Removing it from
    # this range's first open is a dodge; removing seq 13, which no draft kept, is not.
    assert_equal [ 15 ], open_ship(token, 15, 15)["spot_check_seqs"]
    assert_equal [ 18 ], open_ship(token, 13, 18, removing.(13, 15))["spot_check_seqs"]
    assert_equal 1, dodged.call
  end

  test "a gap in the chain is flagged only when kept minutes lie on both sides of it" do
    token = pair_device
    # Seq 1..3, then seq 4..6 forty minutes later, then seq 7..8 after another gap.
    [ 0, 1, 2, 40, 41, 42, 80, 81 ].each { |i| post_minute(token, i, payload(i)) }
    flags = lambda do |from, to, excluded|
      ship = open_ship(token, from, to, excluded)
      post "/api/desktop/v1/ships/#{ship["id"]}/submit", headers: auth(token), as: :json, params: { final_files: [ { path: "a.rb", content: "" } ] }
      assert_response :success
      EvidenceShip.find(ship["id"]).flags
    end
    assert_not_includes flags.(1, 5, [ { from_seq: 4, to_seq: 5 } ]), "unshipped_gaps", "every minute after the gap was removed"
    assert_includes flags.(6, 8, [ { from_seq: 8, to_seq: 8 } ]), "unshipped_gaps", "seq 6 and 7 are kept and 38 minutes apart"
  end

  private

  def auth(token) = { "Authorization" => "Bearer #{token}" }

  # Opens (or updates) the draft over a range; `excluded` is left out of the
  # request unless given, as an app without the timeline editor would.
  def open_ship(token, from_seq, to_seq, excluded = nil)
    post "/api/desktop/v1/ships", params: { project: "sync-app", from_seq:, to_seq:, excluded: }.compact, headers: auth(token), as: :json
    assert_response :created
    response.parsed_body
  end

  def upload_frame(token, ship, frame)
    post "/api/desktop/v1/ships/#{ship["id"]}/frames", params: frame.slice(:hash, :ciphertext, :segment_key), headers: auth(token), as: :json
  end

  # The secret this device's block for minute i is judged by. Only the server
  # knows it before a ship reveals it, so the test reads it from the database.
  def secret_for_minute(i)
    EvidenceBeacon.for_minute!((START + i.minutes).to_i / 60).device_secret(@user.desktop_devices.sole.uid)
  end

  # A frame for minute i that its secret certainly makes required, or certainly does not.
  def frame_with_requirement(i, required)
    secret = secret_for_minute(i)
    loop do
      frame = encrypted_frame("minute #{i}")
      return frame if Evidence::Crypto.required_frame?(secret, frame[:hash], EvidenceShip::REQUIRED_FRAME_RATIO) == required
    end
  end

  # A working tree for minute i whose snapshot its secret certainly picks for a spot-check, or certainly does not.
  def tree_with_spot_check(i, picked)
    secret = secret_for_minute(i)
    loop do
      files = { "app.rb" => "puts 1\n", "pad.rb" => SecureRandom.hex(4) }
      return files if Evidence::Crypto.spot_check?(secret, tree_root(files), EvidenceShip::SPOT_CHECK_RATIO) == picked
    end
  end

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
