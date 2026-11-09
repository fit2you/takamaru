module Takamaru
  # Long-running process (rails takamaru:relay) that publishes the pending commit logs every relay_interval and deletes
  # the old published ones every cleanup_interval. It catches up what CommitLogRelayJob left behind (failed enqueues,
  # broker outages) without a job scheduler. Several replicas can run at the same time.
  class RelayProcess
    def initialize
      @relay = Relay.new
    end

    # Blocks until #stop is called or the process receives INT or TERM; the current batch is completed first.
    def run
      @stopping = false
      ShutdownSignals.trap(-> { stop }) do
        until @stopping
          Rails.application.executor.wrap { run_once }
          wait(Takamaru.config.relay_interval)
        end
      end
    end

    def stop
      @stopping = true
    end

    private

    def run_once
      publish_pending_commit_logs
      cleanup_published_commit_logs
    rescue StandardError => error
      # e.g. the database is unreachable: retry at the next round instead of exiting
      Takamaru.report_error(error)
    end

    def publish_pending_commit_logs
      loop do
        break if @stopping || !@relay.publish_batch
      end
    end

    def cleanup_published_commit_logs
      return if @last_cleanup_at && @last_cleanup_at > Takamaru.config.cleanup_interval.ago

      CommitLogCleanupJob.perform_now
      @last_cleanup_at = Time.current
    end

    # Sleeps in short steps to react quickly to #stop
    def wait(seconds)
      deadline = Time.current + seconds
      sleep(0.5) while !@stopping && Time.current < deadline
    end
  end
end
