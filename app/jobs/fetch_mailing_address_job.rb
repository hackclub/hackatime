class FetchMailingAddressJob < ApplicationJob
  queue_as :default

  Table = Norairrecord.table(ENV["ADDRESS_AIRTABLE_PAT"], "appEC3w8nxAvCwAjL", "tbldZMvkUWGkkteQu")

  def perform(user_id)
    user = User.find(user_id)
    return unless user.mailing_address_otc.present?

    # Search Airtable for the address with this OTC
    records = Table.all(filter: "{OTC} = '#{user.mailing_address_otc}'")
    return if records.empty?

    address_data = records.first.fields

    # Create or update the mailing address
    mailing_address = user.mailing_address || user.build_mailing_address
    mailing_address.update!(
      first_name: address_data["first_name"],
      last_name: address_data["last_name"],
      line_1: address_data["line_1"],
      line_2: address_data["line_2"],
      city: address_data["city"],
      state: address_data["state"],
      zip_code: address_data["zip_code"],
      country: address_data["country"]
    )

    records.first.destroy
  end
end
