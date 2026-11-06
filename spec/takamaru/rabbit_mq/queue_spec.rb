require 'rails_helper'

RSpec.describe(Takamaru::RabbitMq::Queue) do
  subject(:queue) { described_class.new('server.dummies', 'dummies_consumer') }

  let(:bunny_queue) { instance_double(Bunny::Queue) }
  let(:channel) do
    instance_double(Bunny::Channel, ack: nil, close: nil, fanout: exchange, open?: true, prefetch: nil, reject: nil)
  end
  let(:consumer) { instance_double(Bunny::Consumer, cancel: nil) }
  let(:delivery_info) { instance_double(Bunny::DeliveryInfo, delivery_tag: 7) }
  let(:exchange) { instance_double(Bunny::Exchange) }
  let(:reported_errors) { [] }

  before do
    Takamaru.config.error_handler = ->(error, context) { reported_errors << [error, context] }
    session = instance_double(Bunny::Session, create_channel: channel)
    allow(Takamaru::RabbitMq::Connection).to(receive(:session).and_return(session))
    allow(channel).to(receive(:queue).and_return(bunny_queue))
    allow(bunny_queue).to(receive(:bind).with(exchange).and_return(bunny_queue))
    allow(bunny_queue).to(receive(:subscribe).with(manual_ack: true) do |&block|
      @deliver = ->(payload) { block.call(delivery_info, nil, payload) }
      consumer
    end)
    # Instead of waiting for a signal, stops as soon as the subscription has been made
    allow(queue).to(receive(:sleep)) { queue.stop }
  end

  it 'is named after the application and the consumer' do
    expect(queue.name).to(eq('rails_application.dummies_consumer'))
    expect(queue.dead_letter_queue_name).to(eq('rails_application.dummies_consumer.dead'))
  end

  describe '#declare' do
    it 'declares exchange, queues and binding without consuming' do
      queue.declare

      expect(channel).to(have_received(:fanout).with('server.dummies', durable: true))
      expect(channel).to(have_received(:queue).with('rails_application.dummies_consumer.dead', durable: true))
      expect(bunny_queue).to(have_received(:bind).with(exchange))
      expect(bunny_queue).not_to(have_received(:subscribe))
      expect(channel).to(have_received(:close))
    end
  end

  describe '#subscribe' do
    it 'declares durable exchange and queues, with a dead letter queue' do
      queue.subscribe {}

      expect(channel).to(have_received(:fanout).with('server.dummies', durable: true))
      expect(channel).to(have_received(:queue).with('rails_application.dummies_consumer.dead', durable: true))
      expect(channel).to(have_received(:queue).with('rails_application.dummies_consumer', durable: true, arguments: {
        'x-dead-letter-exchange' => '',
        'x-dead-letter-routing-key' => 'rails_application.dummies_consumer.dead',
      }))
      expect(channel).to(have_received(:prefetch).with(10))
    end

    it 'cancels the consumer and closes the channel when stopped' do
      queue.subscribe {}

      expect(consumer).to(have_received(:cancel))
      expect(channel).to(have_received(:close))
    end

    it 'acknowledges a message processed successfully' do
      processed = []
      queue.subscribe { |payload| processed << payload }

      @deliver.call('message')

      expect(processed).to(eq(['message']))
      expect(channel).to(have_received(:ack).with(7))
    end

    it 'dead letters a message that cannot be processed' do
      queue.subscribe { raise 'boom' }

      @deliver.call('message')

      expect(channel).to(have_received(:reject).with(7, false))
      expect(channel).not_to(have_received(:ack))
      expect(reported_errors).to(contain_exactly([
        be_a(RuntimeError),
        { payload: 'message', queue: 'rails_application.dummies_consumer' },
      ]))
    end
  end
end
