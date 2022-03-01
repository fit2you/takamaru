require 'rails_helper'

RSpec.describe(Rabbitmq::Queue) do
  let(:consumer_name) { 'consumer_name' }
  let(:exchange_name) { 'exchange_name' }
  let(:queue) { described_class.new(exchange_name, consumer_name) }
  let(:rails_application_name) { 'rails_application' }

  before do
    allow(Rails.application).to(receive('config_for').with(:rabbitmq).and_return({ 'hostname' => 'localhost' }))
    allow(Rails.application).to(receive('class')).and_return(double(name: '', parent_name: rails_application_name))
  end

  describe('#new') do
    it('initializes a new instance') do
      expect(queue).to(be_a(described_class))
      expect(queue.instance_variable_get(:@exchange_name)).to(eq(exchange_name))
      expect(queue.instance_variable_get(:@name)).to(eq([rails_application_name, consumer_name].join('.')))
    end
  end

  describe('#subscribe') do
    before do
      queue.instance_variable_set(:@options, { hostname: 'localhost' })
      allow(Bunny).to(receive('new').and_return(double(start: nil,
        create_channel: double(fanout: nil, queue: double(bind: nil, subscribe: nil)))))
    end

    it('subscribes to the queue') do
      expect(queue).to(receive(:ensure_connection!).and_call_original)

      queue.subscribe
    end
  end
end
