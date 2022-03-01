class DummyClient < Takamaru::ApplicationClient
  class << self
    def dummy_shadowable(id)
    end

    def dummy_shadowable_by(attribute, value)
    end
  end
end
