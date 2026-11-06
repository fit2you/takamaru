module Takamaru
  # Deletes the commit logs published before Takamaru.config.published_retention (see the takamaru:cleanup rake task).
  class CommitLogCleanupJob < ActiveJob::Base
    queue_as { Takamaru.config.job_queue }

    def perform
      CommitLog.published_before(Takamaru.config.published_retention.ago).in_batches.delete_all
    end
  end
end
