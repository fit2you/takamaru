require 'rails_helper'

RSpec.describe(Takamaru::UnhandledMessageLog, type: :model) do
  it('should validate presence of consumer') do
    expect(described_class.validators_on(:consumer)).to(include(be_a(ActiveRecord::Validations::PresenceValidator)))
  end

  it('should validate presence of payload') do
    expect(described_class.validators_on(:payload)).to(include(be_a(ActiveRecord::Validations::PresenceValidator)))
  end
end
