require 'rails_helper'

RSpec.describe(Takamaru::CommitLoggable) do
  let(:exchange_name) { 'rails_application.dummy_commit_loggables' }

  def last_payload
    Takamaru::CommitLog.last.payload
  end

  describe 'commit logs' do
    it 'logs a create' do
      record = nil

      expect { record = DummyCommitLoggable.create!(name: 'foo') }.to(change { Takamaru::CommitLog.count }.by(1))
      expect(Takamaru::CommitLog.last.exchange_name).to(eq(exchange_name))
      expect(last_payload).to(eq('event' => 'create', 'id' => record.id))
    end

    it 'logs an update with changes' do
      record = DummyCommitLoggable.create!(name: 'foo')

      expect { record.update!(name: 'bar') }.to(change { Takamaru::CommitLog.count }.by(1))
      expect(last_payload).to(eq('event' => 'update', 'id' => record.id))
    end

    it 'does not log an update without changes' do
      record = DummyCommitLoggable.create!(name: 'foo')

      expect { record.save! }.not_to(change { Takamaru::CommitLog.count })
    end

    it 'logs a destroy' do
      record = DummyCommitLoggable.create!(name: 'foo')

      expect { record.destroy! }.to(change { Takamaru::CommitLog.count }.by(1))
      expect(last_payload).to(eq('event' => 'destroy', 'id' => record.id))
    end

    it 'logs every change made in the same transaction' do
      expect do
        DummyCommitLoggable.transaction do
          record = DummyCommitLoggable.create!(name: 'foo')
          record.update!(name: 'bar')
        end
      end.to(change { Takamaru::CommitLog.count }.by(2))
    end

    it 'discards the commit logs of a rolled back transaction' do
      expect do
        DummyCommitLoggable.transaction do
          DummyCommitLoggable.create!(name: 'foo')
          raise ActiveRecord::Rollback
        end
      end.not_to(change { Takamaru::CommitLog.count })
    end
  end

  describe 'relay enqueuing' do
    it 'enqueues the relay once per committed transaction' do
      expect do
        DummyCommitLoggable.transaction do
          record = DummyCommitLoggable.create!(name: 'foo')
          record.update!(name: 'bar')
        end
      end.to(have_enqueued_job(Takamaru::CommitLogRelayJob).exactly(:once))
    end

    it 'enqueues the relay once for many records changed in the same transaction' do
      records = Array.new(3) { |index| DummyCommitLoggable.create!(name: "foo #{index}") }

      expect do
        DummyCommitLoggable.transaction do
          records.each { |record| record.update!(name: "#{record.name} bar") }
          DummyCommitLoggable.create!(name: 'baz')
        end
      end.to(have_enqueued_job(Takamaru::CommitLogRelayJob).exactly(:once))
    end

    it 'enqueues the relay once when changes are made in committed savepoints' do
      expect do
        DummyCommitLoggable.transaction do
          DummyCommitLoggable.create!(name: 'foo')
          DummyCommitLoggable.transaction(requires_new: true) { DummyCommitLoggable.create!(name: 'bar') }
          DummyCommitLoggable.transaction(requires_new: true) { DummyCommitLoggable.create!(name: 'baz') }
        end
      end.to(have_enqueued_job(Takamaru::CommitLogRelayJob).exactly(:once))
    end

    it 'enqueues the relay once per transaction' do
      expect do
        DummyCommitLoggable.create!(name: 'foo')
        DummyCommitLoggable.create!(name: 'bar')
      end.to(have_enqueued_job(Takamaru::CommitLogRelayJob).exactly(:twice))
    end

    it 'enqueues the relay when only a savepoint was rolled back' do
      expect do
        DummyCommitLoggable.transaction do
          DummyCommitLoggable.create!(name: 'foo')
          DummyCommitLoggable.transaction(requires_new: true) do
            DummyCommitLoggable.create!(name: 'bar')
            raise ActiveRecord::Rollback
          end
        end
      end.to(have_enqueued_job(Takamaru::CommitLogRelayJob).exactly(:once))
    end

    it 'does not enqueue the relay when the only changes were in a rolled back savepoint' do
      expect do
        DummyCommitLoggable.transaction do
          DummyCommitLoggable.transaction(requires_new: true) do
            DummyCommitLoggable.create!(name: 'foo')
            raise ActiveRecord::Rollback
          end
        end
      end.not_to(have_enqueued_job(Takamaru::CommitLogRelayJob))
    end

    it 'does not enqueue the relay after a rolled back transaction' do
      expect do
        DummyCommitLoggable.transaction do
          DummyCommitLoggable.create!(name: 'foo')
          raise ActiveRecord::Rollback
        end
      end.not_to(have_enqueued_job(Takamaru::CommitLogRelayJob))
    end

    it 'does not enqueue the relay when nothing was logged' do
      record = DummyCommitLoggable.create!(name: 'foo')

      expect { record.save! }.not_to(have_enqueued_job(Takamaru::CommitLogRelayJob))
    end

    it 'does not enqueue the relay after a rollback followed by a commit without changes' do
      record = DummyCommitLoggable.create!(name: 'foo')
      DummyCommitLoggable.transaction do
        record.update!(name: 'bar')
        raise ActiveRecord::Rollback
      end

      expect { record.save! }.not_to(have_enqueued_job(Takamaru::CommitLogRelayJob))
    end

    it 'reports an enqueue failure without raising' do
      reported_errors = []
      Takamaru.config.error_handler = ->(error, _context) { reported_errors << error }
      allow(Takamaru::CommitLogRelayJob).to(receive(:perform_later).and_raise('queue down'))

      expect { DummyCommitLoggable.create!(name: 'foo') }.to(change { Takamaru::CommitLog.count }.by(1))
      expect(reported_errors).to(contain_exactly(an_object_having_attributes(
        class: Takamaru::EnqueueError,
        cause: an_object_having_attributes(message: 'queue down'),
      )))
    end
  end

  describe '.commit_log_attributes' do
    let(:record) { DummyRoleCommitLoggable.create!(name: 'foo', role: :vendor) }

    def attributes_of_last_payload
      last_payload.fetch('attributes')
    end

    it 'adds the attributes to the payload of a create, without previous values' do
      record

      expect(last_payload).to(eq(
        'event' => 'create',
        'id' => record.id,
        'attributes' => {
          'role' => { 'previous' => nil, 'current' => 'vendor' },
          'name' => { 'previous' => nil, 'current' => 'foo' },
        },
      ))
    end

    it 'adds the previous and current values to the payload of an update (enums by name)' do
      record.update!(role: :dealer)

      expect(attributes_of_last_payload).to(eq(
        'role' => { 'previous' => 'vendor', 'current' => 'dealer' },
        'name' => { 'previous' => 'foo', 'current' => 'foo' },
      ))
    end

    it 'uses the values of the last save, also when the record is saved twice in a transaction' do
      DummyRoleCommitLoggable.transaction do
        record.update!(role: :dealer)
        record.update!(name: 'bar')
      end

      expect(Takamaru::CommitLog.last(2).map { |commit_log| commit_log.payload['attributes'] }).to(eq([
        { 'role' => { 'previous' => 'vendor', 'current' => 'dealer' }, 'name' => { 'previous' => 'foo', 'current' => 'foo' } },
        { 'role' => { 'previous' => 'dealer', 'current' => 'dealer' }, 'name' => { 'previous' => 'foo', 'current' => 'bar' } },
      ]))
    end

    it 'adds the values of the destroyed record to the payload of a destroy' do
      record.destroy!

      expect(last_payload).to(include('event' => 'destroy', 'id' => record.id))
      expect(attributes_of_last_payload).to(eq(
        'role' => { 'previous' => 'vendor', 'current' => 'vendor' },
        'name' => { 'previous' => 'foo', 'current' => 'foo' },
      ))
    end

    it 'adds nothing to the payload of the models not declaring them' do
      DummyCommitLoggable.create!(name: 'foo')

      expect(last_payload.keys).to(eq(%w[event id]))
    end
  end

  describe '#without_commit_log' do
    it 'does not log the changes made inside the block' do
      record = DummyCommitLoggable.new(name: 'foo')

      expect { record.without_commit_log(&:save!) }.not_to(change { Takamaru::CommitLog.count })
    end

    it 'logs again after the block raised' do
      record = DummyCommitLoggable.create!(name: 'foo')

      expect { record.without_commit_log { raise 'boom' } }.to(raise_error('boom'))
      expect { record.update!(name: 'bar') }.to(change { Takamaru::CommitLog.count }.by(1))
    end
  end

  describe '.override_takamaru_class_name' do
    let(:subclass) do
      Class.new(DummyCommitLoggable) do
        class << self
          def name
            'SpecialDummyCommitLoggable'
          end
        end
      end
    end

    it 'changes the exchange name of the class only' do
      subclass.override_takamaru_class_name('specials')

      subclass.create!(name: 'foo')
      expect(Takamaru::CommitLog.last.exchange_name).to(eq('rails_application.specials'))

      DummyCommitLoggable.create!(name: 'foo')
      expect(Takamaru::CommitLog.last.exchange_name).to(eq(exchange_name))
    end
  end
end
