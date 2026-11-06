require 'rails_helper'

RSpec.describe(Takamaru::CommitLogRelayJob) do
  let(:relay) { instance_double(Takamaru::Relay) }

  before do
    allow(Takamaru::Relay).to(receive(:new).and_return(relay))
  end

  it 'enqueues itself again when more commit logs may be pending' do
    allow(relay).to(receive(:publish_batch).and_return(true))

    expect { described_class.perform_now }.to(have_enqueued_job(described_class))
  end

  it 'stops when the pending commit logs have been published' do
    allow(relay).to(receive(:publish_batch).and_return(false))

    expect { described_class.perform_now }.not_to(have_enqueued_job(described_class))
  end
end
