class EmailAddress < ApplicationRecord
  belongs_to :user
  has_paper_trail

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  enum :source, { signing_in: 0, github: 1, slack: 2, preserved_for_deletion: 3 }, prefix: true

  before_validation :downcase_email

  def can_unlink? = !(source_github? || source_slack? || source_preserved_for_deletion?)

  private

  def downcase_email = self.email = email.downcase
end
