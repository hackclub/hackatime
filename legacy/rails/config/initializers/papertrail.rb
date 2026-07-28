class PaperTrail::Version < ActiveRecord::Base
  include PaperTrail::VersionConcern

  self.table_name = "versions"
end
