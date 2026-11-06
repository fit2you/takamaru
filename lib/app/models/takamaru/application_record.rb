module Takamaru
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    class << self
      def table_name_prefix
        'takamaru_'
      end
    end
  end
end
