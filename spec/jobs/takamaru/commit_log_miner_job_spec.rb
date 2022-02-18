require 'rails_helper'

RSpec.describe(Takamaru::CommitLogMinerJob) do
  describe '.perform' do
    let(:commit_log) { create(:commit_log) }
    let(:rabbit_mq_publisher_instance) { instance_double(RabbitMQ::Publisher) }

    before :each do
      allow(RabbitMQ::Publisher).to(receive(:new).and_return(rabbit_mq_publisher_instance))
    end

    it('calls RabbitMQ::Publisher#publish once and destroys all the published commit logs') do
      expect(RabbitMQ::Publisher).to(receive(:new).with(commit_log.exchange_name).once)
      expect(rabbit_mq_publisher_instance).to(receive(:publish).with(commit_log.payload.to_json).once)

      expect { Takamaru::CommitLogMinerJob.perform_now }.to(change { Takamaru::CommitLog.count }.by(-1))
    end
  end
end
