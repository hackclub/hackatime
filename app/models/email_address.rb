class EmailAddress < ApplicationRecord
  belongs_to :user
  has_paper_trail

  validates :email, presence: true,
                   uniqueness: true,
                   format: { with: URI::MailTo::EMAIL_REGEXP }

  enum :source, {
    signing_in: 0,
    github: 1,
    slack: 2,
    preserved_for_deletion: 3
  }, prefix: true

  before_validation :downcase_email

  def can_unlink?
    !(self.source_github? || self.source_slack? || self.source_preserved_for_deletion?)
  end

  private

  def downcase_email
    self.email = email.downcase
  end
end
