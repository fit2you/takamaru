require 'rails_helper'

RSpec.describe(Takamaru::Relay) do
  subject(:relay) { described_class.new }

  let(:publisher) { instance_double(Takamaru::RabbitMq::Publisher, publish: nil) }
  let(:reported_errors) { [] }

  before do
    Takamaru.config.error_handler = ->(error, _context) { reported_errors << error }
    allow(Takamaru::RabbitMq::Publisher).to(receive(:open).and_yield(publisher))
  end

  it 'publishes the pending commit logs in order and marks them as published' do
    first, second = create_list(:commit_log, 2)
    create(:commit_log, published_at: 1.hour.ago)

    relay.publish_batch

    expect(publisher).to(have_received(:publish).ordered.with(
      first.exchange_name,
      first.message.to_json,
      message_id: first.message_id,
      timestamp: first.created_at,
      type: 'update',
    ))
    expect(publisher).to(have_received(:publish).ordered.with(second.exchange_name, any_args))
    expect(Takamaru::CommitLog.pending).to(be_empty)
  end

  it 'stops at the first failure and keeps the remaining commit logs pending' do
    failing, following = create_list(:commit_log, 2)
    allow(publisher).to(receive(:publish).with(failing.exchange_name, any_args)
      .and_raise(Takamaru::PublishError, 'not confirmed'))

    relay.publish_batch

    expect(publisher).not_to(have_received(:publish).with(following.exchange_name, any_args))
    expect(failing.reload).to(have_attributes(attempts: 1, last_error: 'Takamaru::PublishError: not confirmed'))
    expect(Takamaru::CommitLog.pending).to(contain_exactly(failing, following))
    expect(reported_errors.map(&:message)).to(eq(['not confirmed']))
  end

  it 'keeps the commit logs pending when the broker is unreachable' do
    create(:commit_log)
    allow(Takamaru::RabbitMq::Publisher).to(receive(:open).and_call_original)
    allow(Takamaru::RabbitMq::Connection).to(receive(:session).and_raise(Bunny::TCPConnectionFailedForAllHosts))

    expect { relay.publish_batch }.not_to(change { Takamaru::CommitLog.pending.count })
    expect(reported_errors).to(contain_exactly(an_object_having_attributes(
      class: Takamaru::PublishError,
      cause: be_a(Bunny::TCPConnectionFailedForAllHosts),
    )))
  end

  it 'does not connect to the broker when there is nothing to publish' do
    relay.publish_batch

    expect(Takamaru::RabbitMq::Publisher).not_to(have_received(:open))
  end

  it 'does nothing while publishing is disabled' do
    create(:commit_log)
    Takamaru.config.publishing_enabled = false

    expect { relay.publish_batch }.not_to(change { Takamaru::CommitLog.pending.count })
  end

  it 'tells whether more commit logs may be pending' do
    Takamaru.config.relay_batch_size = 2
    create_list(:commit_log, 3)

    expect(relay.publish_batch).to(be(true))
    expect(relay.publish_batch).to(be(false))
    expect(Takamaru::CommitLog.pending).to(be_empty)
  ensure
    Takamaru.config.relay_batch_size = 100
  end

  it 'skips the commit logs locked by a concurrent run', :committed do
    locked, free = create_list(:commit_log, 2)
    row_locked = Thread::Queue.new
    release = Thread::Queue.new

    concurrent_run = Thread.new do
      Takamaru::CommitLog.transaction do
        Takamaru::CommitLog.lock.find(locked.id)
        row_locked << true
        release.pop
      end
    end
    row_locked.pop
    relay.publish_batch
    release << true
    concurrent_run.join

    expect(publisher).to(have_received(:publish).once.with(free.exchange_name, any_args))
    expect(locked.reload.published_at).to(be_nil)
  end

  it 'publishes the commit logs written by a CommitLoggable model' do
    DummyCommitLoggable.create!(name: 'foo')
    relay.publish_batch

    expect(publisher).to(have_received(:publish).with('rails_application.dummy_commit_loggables', any_args))
    expect(Takamaru::CommitLog.pending).to(be_empty)
  end
end
