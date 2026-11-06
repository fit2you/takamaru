require 'rails_helper'

RSpec.describe(Takamaru::RabbitMq::Declaration) do
  let(:bunny_queue) { instance_double(Bunny::Queue) }
  let(:channel) { instance_double(Bunny::Channel, fanout: exchange) }
  let(:exchange) { instance_double(Bunny::Exchange) }

  before do
    allow(channel).to(receive(:queue).and_return(bunny_queue))
    allow(bunny_queue).to(receive(:bind).with(exchange).and_return(bunny_queue))
  end

  describe '.declare' do
    it 'declares the durable exchange, the queue with its dead letter queue and the binding' do
      described_class.declare(channel, exchange_name: 'server.dummies', queue_name: 'app.dummies_consumer')

      expect(channel).to(have_received(:fanout).with('server.dummies', durable: true))
      expect(channel).to(have_received(:queue).with('app.dummies_consumer.dead', durable: true))
      expect(channel).to(have_received(:queue).with('app.dummies_consumer', durable: true, arguments: {
        'x-dead-letter-exchange' => '',
        'x-dead-letter-routing-key' => 'app.dummies_consumer.dead',
      }))
      expect(bunny_queue).to(have_received(:bind).with(exchange))
    end
  end

  describe '.declare_topology' do
    it 'declares the queues of all the consumers, yielding queue and exchange names' do
      topology = Takamaru::Topology.new(
        'application_name' => 'app',
        'consumers' => { 'dummies_consumer' => 'server.dummies', 'others_consumer' => 'server.others' },
      )

      declared = []
      described_class.declare_topology(channel, topology) { |queue_name, exchange_name| declared << [queue_name, exchange_name] }

      expect(declared).to(eq([%w[app.dummies_consumer server.dummies], %w[app.others_consumer server.others]]))
      expect(channel).to(have_received(:fanout).with('server.others', durable: true))
    end
  end
end
