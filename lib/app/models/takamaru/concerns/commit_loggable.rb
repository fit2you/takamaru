module Takamaru
  # Transactional outbox: every create, update and destroy of the including model writes a commit log in the same
  # transaction, and the relay is enqueued once the transaction is committed.
  #
  # Changes that skip callbacks (update_columns, update_all, delete, delete_all, insert_all, upsert_all) are not logged.
  module CommitLoggable
    extend ActiveSupport::Concern

    included do
      # Last part of the exchange name "<application name>.<takamaru_class_name>"
      class_attribute :takamaru_class_name, instance_accessor: false, default: name.tableize

      after_create { log_commit(:create) }
      after_update { log_commit(:update) if saved_changes? }
      after_destroy { log_commit(:destroy) }

      after_commit :enqueue_commit_log_relay
      after_rollback { @commit_log_pending = false }
    end

    class_methods do
      def override_takamaru_class_name(class_name)
        self.takamaru_class_name = class_name
      end
    end

    def without_commit_log
      @commit_log_disabled = true
      yield(self)
    ensure
      @commit_log_disabled = false
    end

    private

    def log_commit(event)
      return if @commit_log_disabled

      CommitLog.create!(exchange_name: commit_log_exchange_name, payload: { 'event' => event.to_s, 'id' => id })
      @commit_log_pending = true
    end

    def commit_log_exchange_name
      "#{Takamaru.rails_application_name}.#{self.class.takamaru_class_name}"
    end

    # The commit log is already committed: if the job cannot be enqueued, the periodic relay will publish it.
    def enqueue_commit_log_relay
      return unless @commit_log_pending

      @commit_log_pending = false
      CommitLogRelayJob.perform_later
    rescue StandardError => error
      Takamaru.report_error(error)
    end
  end
end
