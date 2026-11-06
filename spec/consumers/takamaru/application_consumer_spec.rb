require 'rails_helper'

RSpec.describe(Takamaru::ApplicationConsumer) do
  describe '.application_consumers' do
    it 'returns the consumers defined by the application' do
      expect(described_class.application_consumers).to(eq([DummiesConsumer]))
    end
  end

  describe '.consumer_name' do
    it 'is the underscored class name without namespace' do
      # a stubbed name: a new subclass would stay among the descendants of the other examples
      allow(DummiesConsumer).to(receive(:name).and_return('Billing::InvoicesConsumer'))

      expect(DummiesConsumer.consumer_name).to(eq('invoices_consumer'))
    end
  end

  describe '.topology_errors' do
    it 'is empty when the consumers match the topology' do
      expect(described_class.topology_errors).to(eq([]))
    end

    it 'reports consumers not declared and declared consumers without class' do
      Takamaru.config.topology = Takamaru::Topology.new(
        'application_name' => 'rails_application',
        'consumers' => { 'others_consumer' => 'server.others' },
      )

      expect(described_class.topology_errors).to(eq([
        'consumer dummies_consumer is not declared in the topology',
        'the topology declares others_consumer, which has no consumer class',
      ]))
    end
  end

  describe '#initialize' do
    it 'reads queue and exchange from the topology' do
      expect(DummiesConsumer.new.queue)
        .to(have_attributes(exchange_name: 'server.dummies', name: 'rails_application.dummies_consumer'))
    end

    it 'raises when the consumer is not declared in the topology' do
      Takamaru.config.topology = Takamaru::Topology.new('application_name' => 'rails_application')

      expect { DummiesConsumer.new }
        .to(raise_error(Takamaru::ConfigurationError, 'Consumer dummies_consumer is not declared in the Takamaru topology'))
    end

    it 'raises without topology' do
      Takamaru.config.topology = nil
      Takamaru.config.topology_path = 'config/takamaru.yml'

      expect { DummiesConsumer.new }.to(raise_error(Takamaru::ConfigurationError, 'config/takamaru.yml is required by the consumers'))
    end
  end
end
