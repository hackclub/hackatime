module Clickhouse
  class Record < ActiveRecord::Base
    self.abstract_class = true

    establish_connection :clickhouse
  end
end
