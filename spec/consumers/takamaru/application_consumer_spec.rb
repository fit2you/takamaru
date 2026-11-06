require 'rails_helper'

RSpec.describe(Takamaru::ApplicationConsumer) do
  describe '.application_consumers' do
    it 'returns the consumers defined by the application' do
      expect(described_class.application_consumers).to(eq([DummiesConsumer]))
    end
  end
end
