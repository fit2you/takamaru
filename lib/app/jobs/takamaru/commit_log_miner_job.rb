module Takamaru
  class CommitLogMinerJob < ActiveJob::Base
    queue_as :takamaru

    def perform(commit_log_id)
      commit_log = Takamaru::CommitLog.find(commit_log_id)
      RabbitMq::Publisher.new(commit_log.exchange_name).publish(commit_log.payload.to_json)
      commit_log.destroy
    end
  end
end
