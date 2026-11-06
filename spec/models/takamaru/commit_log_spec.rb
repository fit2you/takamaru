require 'rails_helper'

RSpec.describe(Takamaru::CommitLog) do
  it 'generates a message id' do
    expect(create(:commit_log).message_id).to(match(/\A\h{8}-\h{4}-\h{4}-\h{4}-\h{12}\z/))
  end

  describe '.pending' do
    it 'returns the commit logs not published yet' do
      pending_commit_log = create(:commit_log)
      create(:commit_log, published_at: Time.current)

      expect(described_class.pending).to(eq([pending_commit_log]))
    end
  end

  describe '.published_before' do
    it 'returns the commit logs published before the given time' do
      old_commit_log = create(:commit_log, published_at: 2.days.ago)
      create(:commit_log, published_at: Time.current)
      create(:commit_log)

      expect(described_class.published_before(1.day.ago)).to(eq([old_commit_log]))
    end
  end

  describe '#message' do
    it 'adds the delivery metadata to the payload' do
      commit_log = create(:commit_log, payload: { 'event' => 'create', 'id' => 42 })

      expect(commit_log.message).to(eq(
        'event' => 'create',
        'id' => 42,
        'message_id' => commit_log.message_id,
        'occurred_at' => commit_log.created_at.utc.iso8601(6),
        'sequence' => commit_log.id,
      ))
    end
  end

  describe '#record_failure!' do
    it 'increments the attempts and stores the error' do
      commit_log = create(:commit_log)

      expect { commit_log.record_failure!(Takamaru::PublishError.new('nope')) }
        .to(change { commit_log.reload.attempts }.from(0).to(1))
      expect(commit_log.last_error).to(eq('Takamaru::PublishError: nope'))
    end
  end
end
