module Takamaru
  # Transactional outbox: every create, update and destroy of the including model writes a commit log in the same
  # transaction, and the relay is enqueued once the transaction is committed: once per transaction, however many
  # records it changed.
  #
  # Changes that skip callbacks (update_columns, update_all, delete, delete_all, insert_all, upsert_all) are not logged.
  module CommitLoggable
    extend ActiveSupport::Concern

    # Enrolled in the transaction of every logged change, like a record, to enqueue the relay when it is committed.
    # Active Record runs the callbacks of each enrolled object once (records.uniq(&:__id__)), also after a savepoint
    # has handed its records over to the parent transaction: being a single shared object, it enqueues the relay once
    # per committed transaction. A rollback drops it together with the records of the rolled back (sub)transaction.
    module RelayEnqueuer
      class << self
        def enroll(connection)
          connection.add_transaction_record(self)
        end

        # Transaction record interface (see ActiveRecord::ConnectionAdapters::Transaction)

        def trigger_transactional_callbacks?
          true
        end

        def before_committed!; end

        def committed!(should_run_callbacks: true)
          enqueue_relay if should_run_callbacks
        end

        def rolledback!(force_restore_state: false, should_run_callbacks: true); end

        private

        # The commit logs are already committed: if the job cannot be enqueued, the relay process publishes them a few
        # seconds later.
        def enqueue_relay
          Takamaru.perform_later!(CommitLogRelayJob)
        rescue EnqueueError => error
          Takamaru.report_error(error)
        end
      end
    end

    included do
      # Last part of the exchange name "<application name>.<takamaru_class_name>"
      class_attribute :takamaru_class_name, instance_accessor: false, default: name.tableize

      after_create { log_commit(:create) }
      after_update { log_commit(:update) if saved_changes? }
      after_destroy { log_commit(:destroy) }
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
      RelayEnqueuer.enroll(self.class.connection)
    end

    def commit_log_exchange_name
      "#{Takamaru.rails_application_name}.#{self.class.takamaru_class_name}"
    end
  end
end
