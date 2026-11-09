module Takamaru
  # Publishes the pending commit logs right after each commit of a CommitLoggable record (see Takamaru::Relay).
  # What it leaves behind (failed enqueues, broker outages) is published by the relay process (rails takamaru:relay).
  class CommitLogRelayJob < ActiveJob::Base
    queue_as { Takamaru.config.job_queue }

    def perform
      self.class.perform_later if Relay.new.publish_batch
    end
  end
end
