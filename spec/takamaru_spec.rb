require 'rails_helper'

RSpec.describe(Takamaru) do
  describe '.gem_version' do
    it 'returns the version of the gem' do
      v = described_class.gem_version
      expect(v).to(be_a(Gem::Version))
      expect(v.to_s).to(eq(Takamaru::VERSION.to_s))
    end
  end

  describe '.configure' do
    it 'yields the configuration' do
      described_class.configure { |config| config.consumer_prefetch = 1 }

      expect(described_class.config.consumer_prefetch).to(eq(1))
    ensure
      described_class.config.consumer_prefetch = 10
    end
  end

  describe '.report_error' do
    it 'calls the configured error handler' do
      reported = []
      described_class.config.error_handler = ->(error, context) { reported << [error, context] }
      error = StandardError.new('boom')

      described_class.report_error(error, foo: 'bar')

      expect(reported).to(eq([[error, { foo: 'bar' }]]))
    end
  end
end
