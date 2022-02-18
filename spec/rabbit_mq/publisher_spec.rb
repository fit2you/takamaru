require 'rails_helper'

RSpec.describe(RabbitMQ::Publisher) do
  describe('#publish') do
    let(:bunny_channel_instance) { Bunny::Channel.new(connection, 42) }
    let(:bunny_exchange_instance) { instance_double(Bunny::Exchange) }
    let(:bunny_instance) { Bunny.new }
    let(:connection) { Bunny::Session.new }
    let(:exchange_name) { 'exchange_name' }
    let(:message) { 'foo' }
    let(:subject) { described_class.new(exchange_name) }

    before(:each) do
      allow(Bunny).to(receive(:new).and_return(bunny_instance))
      allow(bunny_channel_instance).to(receive(:fanout).with(exchange_name).and_return(bunny_exchange_instance))
      allow(bunny_exchange_instance).to(receive(:name).and_return(exchange_name))
      allow(bunny_exchange_instance).to(receive(:publish))
      allow(bunny_instance).to(receive(:create_channel).and_return(bunny_channel_instance))
      allow(bunny_instance).to(receive(:start).and_return(bunny_instance))

      allow(Rails.application).to(receive('config_for').with(:rabbit_mq).and_return({ 'hostname' => 'localhost' }))
    end

    it('calls exchange.publish once') do
      expect(Rails.logger).to(receive(:debug).with("[RabbitMQ] Publishing message: #{message} to #{exchange_name}"))
      expect(bunny_exchange_instance).to(receive('publish').with(message).once)

      subject.publish(message)
    end
  end
end
