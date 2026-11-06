require 'rails_helper'

RSpec.describe(Takamaru::RabbitMq::Connection) do
  let(:session) { instance_double(Bunny::Session, close: nil, open?: true, start: nil) }

  before do
    allow(Bunny).to(receive(:new).and_return(session))
  end

  after do
    described_class.close
  end

  it 'opens one session with the configured options and shares it' do
    first = described_class.session
    second = described_class.session

    expect(first).to(be(second))
    expect(Bunny).to(have_received(:new).once.with(
      hostname: 'localhost',
      password: 'guest',
      port: 5672,
      username: 'guest',
      vhost: '/',
    ))
    expect(session).to(have_received(:start).once)
  end

  it 'opens a new session when the current one was closed' do
    described_class.session
    allow(session).to(receive(:open?).and_return(false))

    described_class.session

    expect(Bunny).to(have_received(:new).twice)
  end

  it 'opens a new session in a forked process' do
    described_class.session
    allow(Process).to(receive(:pid).and_return(Process.pid + 1))

    described_class.session

    expect(Bunny).to(have_received(:new).twice)
  end
end
