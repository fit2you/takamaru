module Takamaru
  class ApplicationModel < ActiveRecord::Base
    self.abstract_class = true

    def self.table_name_prefix
      'takamaru_'
    end
  end
end
