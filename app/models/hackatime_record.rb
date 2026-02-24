class HackatimeRecord < ApplicationRecord
  self.abstract_class = true

  begin
    connects_to database: { reading: :wakatime, writing: :wakatime }
  rescue StandardError => e
    Rails.logger.warn "HackatimeRecord: Could not connect to wakatime database: #{e.message}"
  end
end
