module HasTableSync
  extend ActiveSupport::Concern

  included do
    validates :airtable_fields, presence: true
    validates :airtable_id, presence: true, uniqueness: true

    def airtable_url
      "https://airtable.com/#{@table_sync_pat}/tbl#{@table_sync_base}/#{airtable_id}"
    end
  end

  class_methods do
    def has_table_sync(pat:, base:, table:)
      @table_sync_pat = pat
      @table_sync_base = base
      @table_sync_table = table

      @table = Norairrecord.table(pat, base, table)

      def pull_all_from_airtable!
        records = @table.all.map { |record| { airtable_id: record.id, airtable_fields: record.fields } }

        upsert_all(records, unique_by: :airtable_id)
      end
    end
  end
end
