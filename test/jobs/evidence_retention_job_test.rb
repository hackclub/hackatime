require "test_helper"

class EvidenceRetentionJobTest < ActiveSupport::TestCase
  test "network metadata is cleared after 30 days except on blocks a reviewer is still looking at" do
    user = create(:user)
    device, = DesktopDevice.build_with_token(user:, name: "Mac", platform: "macos", capture_consented_at: Time.current)
    device.save!
    ja4 = Ja4.resolve("t13d1516h2_8daaf6152771_02713d6af862")
    blocks = (1..4).map do |seq|
      beacon = EvidenceBeacon.for_minute!(EvidenceBeacon.current_minute - 100 + seq)
      device.evidence_blocks.create!(user:, evidence_beacon: beacon, seq:, minute: beacon.minute, prev_hash: "0" * 64, block_hash: SecureRandom.hex(32),
        payload: { focus: "project" }, captured_at_ms: beacon.minute * 60_000, received_at: (seq == 4 ? 29 : 40).days.ago,
        ip_address: "203.0.113.#{seq}", ja4_id: ja4&.id)
    end
    device.update!(last_seq: 4)
    EvidenceShip.create!(user:, desktop_device: device, project: "x", from_seq: 2, to_seq: 2, status: :submitted)
    EvidenceShip.create!(user:, desktop_device: device, project: "x", from_seq: 3, to_seq: 3, status: :approved, decided_at: 1.day.ago)

    EvidenceRetentionJob.perform_now

    kept = blocks.map(&:reload).map { |block| block.ip_address.present? }
    assert_equal [ false, true, false, true ], kept, "cleared when old, kept while under review or younger than 30 days"
    assert_nil blocks[0].ja4_id
  end
end
