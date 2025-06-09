class RawHeartbeatUpload < ApplicationRecord
  has_many :heartbeats

  validates :request_headers, presence: true
  validates :request_body, presence: true
end
