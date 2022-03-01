require 'rails_helper'

RSpec.describe(Takamaru::CommitLogMinerJob) do
  describe '.perform' do
    let(:commit_log) { create(:commit_log) }
    let(:rabbitmq_publisher_instance) { instance_double(Rabbitmq::Publisher) }

    before :each do
      allow(Rabbitmq::Publisher).to(receive(:new).and_return(rabbitmq_publisher_instance))
    end

    it('calls Rabbitmq::Publisher#publish once and destroys all the published commit logs') do
      expect(Rabbitmq::Publisher).to(receive(:new).with(commit_log.exchange_name).once)
      expect(rabbitmq_publisher_instance).to(receive(:publish).with(commit_log.payload.to_json).once)

      expect { Takamaru::CommitLogMinerJob.perform_now }.to(change { Takamaru::CommitLog.count }.by(-1))
    end
  end
end
