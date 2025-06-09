class MailingAddress < ApplicationRecord
  has_paper_trail
  belongs_to :user

  encrypts :first_name, deterministic: true
  encrypts :last_name, deterministic: true
  encrypts :zip_code, deterministic: true
  encrypts :line_1, deterministic: true
  encrypts :line_2, deterministic: true
  encrypts :city, deterministic: true
  encrypts :state, deterministic: true
  encrypts :country, deterministic: true

  after_save :update_user_country_code

  private

  def update_user_country_code
    return unless country.present?

    # Find the country by name and get its ISO code
    country_obj = ISO3166::Country.find_country_by_any_name(country)
    return unless country_obj

    user.update_column(:country_code, country_obj.alpha2)
  end
end
