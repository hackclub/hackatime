require "test_helper"

# Erasing a student removes their devices, chain, ships, frames, frame blobs
# and access log; erasing a reviewer keeps other students' access logs with
# the reviewer shown as deleted.
class DesktopEvidenceErasureTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @student = create(:user, slack_uid: "U_DESK_#{SecureRandom.hex(4)}")
    @reviewer = create(:user, :admin, slack_uid: "U_REV_#{SecureRandom.hex(4)}")
    device, = DesktopDevice.build_with_token(user: @student, name: "Mac", platform: "macos", capture_consented_at: Time.current)
    device.save!
    beacon = EvidenceBeacon.for_minute!(EvidenceBeacon.current_minute)
    hash = Evidence::Crypto.chain_hash(device.head_hash, beacon.value, "{}")
    device.evidence_blocks.create!(user: @student, evidence_beacon: beacon, seq: 1, minute: beacon.minute, prev_hash: device.head_hash,
      block_hash: hash, payload: { focus: "project" }, captured_at_ms: beacon.minute * 60_000, received_at: Time.current)
    device.update!(last_seq: 1, head_hash: hash)
    @ship = EvidenceShip.create!(user: @student, desktop_device: device, project: "x", from_seq: 1, to_seq: 1, reviewer: @reviewer)
    frame = @ship.evidence_frames.create!(frame_hash: "a" * 64, seq: 1, captured_at_ms: 1, kind: "timelapse", segment_key: Base64.strict_encode64("k" * 32))
    frame.ciphertext.attach(io: StringIO.new("cipher"), filename: "f.bin")
    @blob_key = frame.ciphertext.blob.key
    @ship.log_view!(viewer: @reviewer, action: "frame", frame:)
  end

  teardown do
    [ @student, @reviewer ].each do |user|
      Privacy::Eraser.new(claims(user)).call(action: "delete") if User.exists?(user.id)
    end
  end

  def claims(user) = { "request_id" => SecureRandom.uuid, "dry_run" => false, "subject" => { "emails" => [], "slack_id" => user.slack_uid } }

  test "erasing the reviewer keeps the student's access log with the reviewer removed" do
    result = Privacy::Eraser.new(claims(@reviewer)).call(action: "delete")
    assert_includes result[:retained].map { |entry| entry[:type] }, "evidence_views.viewer_id"
    assert_nil @ship.evidence_views.sole.reload.viewer_id
    assert_nil @ship.reload.reviewer_id
  end

  test "erasing the student removes every desktop and evidence row and the frame blob" do
    result = Privacy::Eraser.new(claims(@student)).call(action: "delete")
    %w[desktop_devices evidence_blocks evidence_ships evidence_frames evidence_views].each do |table|
      assert_equal 1, result[:deleted][table], "#{table} should be erased"
    end
    assert_not ActiveStorage::Blob.exists?(key: @blob_key)
    assert_not ActiveStorage::Blob.service.exist?(@blob_key)
    assert User.exists?(@reviewer.id)
  end
end
