require 'rails_helper'

RSpec.describe(Takamaru) do
  describe '.gem_version' do
    it 'returns the version of the gem' do
      v = described_class.gem_version
      expect(v).to(be_a(::Gem::Version))
      expect(v.to_s).to(eq(::Takamaru::VERSION.to_s))
    end
  end
end
