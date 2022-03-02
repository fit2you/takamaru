class DummyClient < Takamaru::ApplicationClient
  class << self
    def dummy(id)
    end

    def dummy_by(attribute, value)
    end
  end
end
