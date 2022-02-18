class DummyClient < ApplicationClient
  class << self
    def dummy_finder_method(id)
    end

    def dummy_finder_by_method(attribute, value)
    end
  end
end
