require 'rails_helper'

RSpec.describe(DummiesConsumer) do
  subject(:consumer) { described_class.new }

  let(:message) do
    { 'event' => 'update', 'id' => 42, 'message_id' => 'uuid', 'occurred_at' => '2026-11-03T10:00:00Z', 'sequence' => 7 }
  end

  def consume(payload)
    allow(consumer.queue).to(receive(:subscribe)) { |&block| block.call(payload) }
    consumer.consume
  end

  it 'consumes the queue named after the consumer' do
    expect(consumer.queue).to(have_attributes(exchange_name: 'server.dummies', name: 'rails_application.dummies_consumer'))
  end

  %w[create destroy update].each do |event|
    it "enqueues the consumer job for a #{event} event" do
      expect { consume(message.merge('event' => event).to_json) }.to(have_enqueued_job(DummiesConsumerJob).with(
        42,
        event,
        { 'message_id' => 'uuid', 'occurred_at' => '2026-11-03T10:00:00Z', 'sequence' => 7 },
      ))
    end
  end

  it 'rejects an unknown event' do
    expect { consume(message.merge('event' => 'instance_eval').to_json) }
      .to(raise_error(ArgumentError, 'Unknown event "instance_eval"'))
  end

  it 'rejects an invalid payload' do
    expect { consume('invalid') }.to(raise_error(JSON::ParserError))
  end

  it 'stops the queue' do
    allow(consumer.queue).to(receive(:stop))

    consumer.stop

    expect(consumer.queue).to(have_received(:stop))
  end
end
