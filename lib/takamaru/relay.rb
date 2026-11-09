module Takamaru
  # Publishes the pending commit logs in insertion order, one batch at a time.
  #
  # Concurrent runs are safe: each one locks its own batch with FOR UPDATE SKIP LOCKED, so a commit log is never
  # published twice at the same time. The lock is held while publishing, so keep relay_batch_size small.
  class Relay
    # Returns true when a whole batch was published, i.e. more commit logs may be pending.
    def publish_batch
      return false unless Takamaru.config.publishing_enabled

      published_count = CommitLog.transaction { publish_in_order(lock_pending_batch) }
      published_count == batch_size
    rescue PublishError, Bunny::Exception => error
      # Broker unreachable (PublishError) or misconfigured: the commit logs stay pending and the next run retries them.
      Takamaru.report_error(error)
      false
    end

    private

    def batch_size
      Takamaru.config.relay_batch_size
    end

    def lock_pending_batch
      CommitLog.pending.order(:id).limit(batch_size).lock('FOR UPDATE SKIP LOCKED').to_a
    end

    # Stops at the first failure, so that the remaining commit logs are retried by the next run in the same order.
    def publish_in_order(commit_logs)
      return 0 if commit_logs.empty?

      RabbitMq::Publisher.open do |publisher|
        commit_logs.take_while { |commit_log| publish(publisher, commit_log) }.size
      end
    end

    def publish(publisher, commit_log)
      publisher.publish(
        commit_log.exchange_name,
        commit_log.message.to_json,
        message_id: commit_log.message_id,
        timestamp: commit_log.created_at,
        type: commit_log.payload['event'],
      )
      commit_log.mark_as_published!
      true
    rescue StandardError => error
      commit_log.record_failure!(error)
      Takamaru.report_error(error, commit_log_id: commit_log.id)
      false
    end
  end
end
