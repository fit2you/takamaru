require 'rails_helper'

RSpec.describe(Takamaru::RelayProcess) do
  subject(:relay_process) { described_class.new }

  let(:relay) { instance_double(Takamaru::Relay) }
  let(:reported_errors) { [] }

  before do
    Takamaru.config.error_handler = ->(error, _context) { reported_errors << error }
    Takamaru.config.relay_interval = 0
    allow(Takamaru::Relay).to(receive(:new).and_return(relay))
    allow(Takamaru::CommitLogCleanupJob).to(receive(:perform_now))
  end

  after do
    Takamaru.config.relay_interval = 5
  end

  # Stops the process at the given call of Relay#publish_batch, which returns the given values in turn
  def stop_at_call(count, results = [false])
    calls = 0
    allow(relay).to(receive(:publish_batch)) do
      calls += 1
      relay_process.stop if calls == count
      results.fetch(calls - 1, false)
    end
  end

  it 'publishes batches until nothing more is pending' do
    stop_at_call(4, [true, true, false])

    relay_process.run

    expect(relay).to(have_received(:publish_batch).exactly(4).times)
  end

  it 'deletes the old published commit logs once per cleanup interval' do
    stop_at_call(3)

    relay_process.run

    expect(Takamaru::CommitLogCleanupJob).to(have_received(:perform_now).once)
  end

  it 'keeps running after an error' do
    calls = 0
    allow(relay).to(receive(:publish_batch)) do
      relay_process.stop if (calls += 1) == 2
      raise ActiveRecord::ConnectionNotEstablished
    end

    relay_process.run

    expect(reported_errors).to(contain_exactly(
      be_a(ActiveRecord::ConnectionNotEstablished),
      be_a(ActiveRecord::ConnectionNotEstablished),
    ))
  end

  it 'stops on TERM' do
    allow(relay).to(receive(:publish_batch)) do
      Process.kill('TERM', Process.pid)
      false
    end

    relay_process.run

    expect(relay).to(have_received(:publish_batch).at_least(:once))
  end
end
