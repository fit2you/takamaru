require 'rails_helper'

RSpec.describe(Takamaru::CommitLogCleanupJob) do
  it 'deletes the commit logs published before the retention period' do
    create(:commit_log, published_at: 8.days.ago)
    recently_published = create(:commit_log, published_at: 6.days.ago)
    pending = create(:commit_log)

    described_class.perform_now

    expect(Takamaru::CommitLog.all).to(contain_exactly(recently_published, pending))
  end
end
