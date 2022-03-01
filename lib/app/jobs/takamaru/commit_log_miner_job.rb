module Takamaru
  class CommitLogMinerJob < ActiveJob::Base
    def perform
      ActiveRecord::Base.transaction do
        ids = []
        begin
          CommitLog.find_each do |commit_log|
            Rabbitmq::Publisher.new(commit_log.exchange_name).publish(commit_log.payload.to_json)
            ids << commit_log.id
          end
        ensure
          CommitLog.where(id: ids).destroy_all
        end
      end
    end
  end
end
