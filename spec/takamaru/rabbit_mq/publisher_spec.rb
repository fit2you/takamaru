require 'rails_helper'

RSpec.describe(Takamaru::RabbitMq::Publisher) do
  let(:channel) { instance_double(Bunny::Channel, close: nil, confirm_select: nil, open?: true, wait_for_confirms: true) }
  let(:exchange) { instance_double(Bunny::Exchange, publish: nil) }
  let(:occurred_at) { Time.utc(2026, 11, 3, 10) }

  before do
    session = instance_double(Bunny::Session, create_channel: channel)
    allow(Takamaru::RabbitMq::Connection).to(receive(:session).and_return(session))
    allow(channel).to(receive(:fanout).with('app.users', durable: true).and_return(exchange))
  end

  def publish
    described_class.open do |publisher|
      publisher.publish('app.users', '{"id":42}', message_id: 'uuid', timestamp: occurred_at, type: 'update')
    end
  end

  it 'publishes a persistent message on a durable exchange with confirms enabled' do
    publish

    expect(channel).to(have_received(:confirm_select))
    expect(exchange).to(have_received(:publish).with(
      '{"id":42}',
      content_type: 'application/json',
      message_id: 'uuid',
      persistent: true,
      timestamp: occurred_at.to_i,
      type: 'update',
    ))
    expect(channel).to(have_received(:close))
  end

  it 'raises when the broker does not confirm the message' do
    allow(channel).to(receive(:wait_for_confirms).and_return(false))

    expect { publish }.to(raise_error(Takamaru::PublishError, 'Message uuid not confirmed by app.users'))
    expect(channel).to(have_received(:close))
  end

  it 'raises a PublishError, caused by the network error, when the broker is unreachable' do
    allow(Takamaru::RabbitMq::Connection).to(receive(:session).and_raise(Bunny::TCPConnectionFailedForAllHosts))

    expect { publish }.to(raise_error(Takamaru::PublishError) do |error|
      expect(error).to(be_a(Takamaru::TransientError))
      expect(error.cause).to(be_a(Bunny::TCPConnectionFailedForAllHosts))
    end)
  end

  it 'raises a PublishError when the connection drops while publishing' do
    allow(exchange).to(receive(:publish).and_raise(Bunny::ConnectionClosedError.new(channel)))

    expect { publish }.to(raise_error(Takamaru::PublishError) { |error| expect(error.cause).to(be_a(Bunny::ConnectionClosedError)) })
    expect(channel).to(have_received(:close))
  end

  it 'does not hide configuration errors' do
    allow(channel).to(receive(:fanout).and_raise(Bunny::PreconditionFailed.new('inequivalent arg durable', channel, false)))

    expect { publish }.to(raise_error(Bunny::PreconditionFailed))
  end
end
