class ApiKey < ApplicationRecord
  DEFAULT_NAME = "Hackatime key".freeze

  belongs_to :user

  validates :token, presence: true, uniqueness: true
  validates :name, presence: true, uniqueness: { scope: :user_id }

  before_validation :generate_token!, on: :create

  private

  # WakaTime compatibility: vscode-wakatime expects a UUID v4 token.
  def generate_token!
    self.token ||= SecureRandom.uuid_v4
    self.name ||= DEFAULT_NAME
  end
end
