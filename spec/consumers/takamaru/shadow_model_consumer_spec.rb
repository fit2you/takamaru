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

  describe 'attributes' do
    let(:attributes) { { 'role' => { 'previous' => 'vendor', 'current' => 'dealer' } } }

    it 'passes the attributes to the job with the metadata' do
      expect { consume(message.merge('attributes' => attributes).to_json) }
        .to(have_enqueued_job(DummiesConsumerJob).with(
          42,
          'update',
          { 'attributes' => attributes, 'message_id' => 'uuid', 'occurred_at' => '2026-11-03T10:00:00Z', 'sequence' => 7 },
        ))
    end

    it 'does not enqueue the job of a message not accepted' do
      allow(consumer).to(receive(:accept?).and_return(false))

      expect { consume(message.merge('attributes' => attributes).to_json) }.not_to(have_enqueued_job(DummiesConsumerJob))
      expect(consumer).to(have_received(:accept?).with(hash_including('attributes' => attributes)))
    end

    it 'always accepts a message without attributes' do
      allow(consumer).to(receive(:accept?).and_return(false))

      expect { consume(message.to_json) }.to(have_enqueued_job(DummiesConsumerJob))
      expect(consumer).not_to(have_received(:accept?))
    end

    it 'accepts every message by default' do
      expect { consume(message.merge('attributes' => attributes).to_json) }.to(have_enqueued_job(DummiesConsumerJob))
    end

    describe '#attribute_values' do
      def attribute_values(attributes, name = 'role')
        consumer.send(:attribute_values, message.merge('attributes' => attributes), name)
      end

      it 'returns the previous and current values' do
        expect(attribute_values(attributes)).to(eq(%w[vendor dealer]))
      end

      it 'returns a value once when unchanged' do
        expect(attribute_values('role' => { 'previous' => 'dealer', 'current' => 'dealer' })).to(eq(%w[dealer]))
      end

      it 'skips a nil previous value of a create' do
        expect(attribute_values('role' => { 'previous' => nil, 'current' => 'dealer' })).to(eq(%w[dealer]))
      end

      it 'returns nothing for an attribute not carried' do
        expect(attribute_values(attributes, 'name')).to(eq([]))
        expect(consumer.send(:attribute_values, message, 'role')).to(eq([]))
      end
    end
  end

  it 'rejects an unknown event' do
    expect { consume(message.merge('event' => 'instance_eval').to_json) }
      .to(raise_error(ArgumentError, 'Unknown event "instance_eval"'))
  end

  it 'raises an EnqueueError, caused by the backend error, when the job is not enqueued' do
    allow(DummiesConsumerJob).to(receive(:perform_later).and_raise(Errno::ECONNREFUSED))

    expect { consume(message.to_json) }.to(raise_error(Takamaru::EnqueueError) do |error|
      expect(error.cause).to(be_a(Errno::ECONNREFUSED))
    end)
  end

  it 'raises an EnqueueError when the job backend returns false' do
    allow(DummiesConsumerJob).to(receive(:perform_later).and_return(false))

    expect { consume(message.to_json) }.to(raise_error(Takamaru::EnqueueError, 'DummiesConsumerJob not enqueued'))
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
