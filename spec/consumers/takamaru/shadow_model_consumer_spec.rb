require 'rails_helper'

RSpec.describe(DummiesConsumer) do
  let(:consumer) { described_class.new }
  let(:dummy) { create(:dummy) }

  before do
    allow(Rails.application).to(receive('config_for').with(:rabbitmq).and_return({ 'hostname' => 'localhost' }))
  end

  describe('.new') do
    it('initializes a new instance') do
      expect(consumer).to(be_a(described_class))
      expect(consumer.instance_variable_get(:@queue)).to(be_a(RabbitMq::Queue))
    end
  end

  %i[create destroy update].each do |event|
    describe("#consume_#{event}") do
      it("enqueues a job to #{event} a shadow model") do
        expect(DummiesConsumerJob).to(receive('perform_later').once.with(dummy.id, event.to_s))

        consumer.send(:"consume_#{event}", dummy.id)
      end
    end
  end

  describe('#consume') do
    before do
      consumer.queue.instance_variable_set(:@options, { hostname: 'localhost' })
      allow(Bunny).to(receive('new').and_return(double(start: nil,
        create_channel: double(fanout: nil, queue: double(bind: nil, subscribe: nil)))))
    end

    context('with a valid payload') do
      it('subscribes to the queue') do
        expect(consumer.queue).to(receive('subscribe')).and_call_original

        consumer.consume
      end
    end

    context('with an invalid payload') do
      let(:payload) { 'invalid' }

      before do
        allow_any_instance_of(RabbitMq::Queue).to(receive('subscribe') { |&block| block.call(payload) })
      end

      it('subscribes to the queue') do
        expect(Rollbar).to(receive('critical').once)
        expect { consumer.consume }.to(change { Takamaru::UnhandledMessageLog.count }.by(1))
        expect(Takamaru::UnhandledMessageLog.last.consumer).to(eq(described_class.name))
        expect(Takamaru::UnhandledMessageLog.last.payload).to(eq(payload))
      end
    end
  end

  describe('#send_from_payload') do
    %i[create destroy update].each do |event|
      context("when the event is #{event}") do
        let(:payload) { { event: event, id: dummy.id }.to_json }

        it('calls the appropriate method') do
          expect(consumer).to(receive(:"consume_#{event}").once.with(dummy.id))

          consumer.send(:send_from_payload, payload)
        end
      end
    end
  end
end
