# Access log entry: who opened which part of a ship, shown to its owner.
class EvidenceView < ApplicationRecord
  belongs_to :evidence_ship
  belongs_to :evidence_frame, optional: true
  belongs_to :viewer, class_name: "User", optional: true
end
