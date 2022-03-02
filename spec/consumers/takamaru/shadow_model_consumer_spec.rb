require 'rails_helper'

RSpec.describe(ShadowDummiesConsumer) do
  let(:consumer) { described_class.new }

  before do
    allow(Rails.application).to(receive('config_for').with(:rabbitmq).and_return({ 'hostname' => 'localhost' }))
  end

  describe('.new') do
    it('initializes a new instance') do
      expect(consumer).to(be_a(described_class))
      expect(consumer.instance_variable_get(:@queue)).to(be_a(Rabbitmq::Queue))
    end
  end

  describe('#consume') do
    before do
      consumer.queue.instance_variable_set(:@options, { hostname: 'localhost' })
      allow(Bunny).to(receive('new').and_return(double(start: nil,
        create_channel: double(fanout: nil, queue: double(bind: nil, subscribe: nil)))))
    end

    it('subscribes to the queue') do
      expect(consumer.queue).to(receive('subscribe')).and_call_original

      consumer.consume
    end
  end

  %i[create destroy update].each do |event|
    describe("#consume_#{event}") do
      let(:dummy) { create(:dummy) }

      it("enqueues a job to #{event} a shadow model") do
        expect(ShadowDummiesJob).to(receive('perform_later').once.with(dummy.id, event.to_s))

        consumer.send(:"consume_#{event}", dummy.id)
      end
    end
  end
end
