module Takamaru
  # Transactional outbox: every create, update and destroy of the including model writes a commit log in the same
  # transaction, and the relay is enqueued once the transaction is committed: once per transaction, however many
  # records it changed.
  #
  # Changes that skip callbacks (update_columns, update_all, delete, delete_all, insert_all, upsert_all) are not logged.
  #
  # The payload carries the event and the id of the record, plus the attributes declared with commit_log_attributes,
  # each with its previous and current value, so that consumers can skip the messages they are not interested in
  # without reading the record:
  #
  #   { 'event' => 'update', 'id' => 42, 'attributes' => { 'role' => { 'previous' => 'vendor', 'current' => 'dealer' } } }
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
      # Names of the attributes added to the payload (see commit_log_attributes)
      class_attribute :commit_log_attribute_names, instance_accessor: false, default: [].freeze

      after_create { log_commit(:create) }
      after_update { log_commit(:update) if saved_changes? }
      after_destroy { log_commit(:destroy) }
    end

    class_methods do
      def override_takamaru_class_name(class_name)
        self.takamaru_class_name = class_name
      end

      # Adds attributes to the payload, to let the consumers filter the messages (e.g. the role of a user): keep them
      # few and small, the consumers still read the state of the record. Each one is rendered as
      # { 'previous' => ..., 'current' => ... }:
      # - create: previous nil, current the created value;
      # - update: previous the value before the save (equal to current when unchanged), current the saved one;
      # - destroy: previous and current the value of the destroyed record.
      # A consumer interested in some values accepts a message when previous or current is one of them: a record
      # leaving those values (e.g. a vendor becoming a dealer) is notified too.
      def commit_log_attributes(*names)
        self.commit_log_attribute_names = names.map(&:to_s).freeze
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

      CommitLog.create!(exchange_name: commit_log_exchange_name, payload: commit_log_payload(event))
      RelayEnqueuer.enroll(self.class.connection)
    end

    def commit_log_payload(event)
      payload = { 'event' => event.to_s, 'id' => id }
      names = self.class.commit_log_attribute_names
      payload['attributes'] = names.to_h { |name| [name, commit_log_attribute(event, name)] } if names.any?
      payload
    end

    # Called in the after_create, after_update and after_destroy callbacks, where the saved changes are those of the
    # save just made. Attribute values (enums by name), not readers: previous and current are read the same way.
    def commit_log_attribute(event, name)
      current = self[name]
      previous = case event
      when :create then nil
      when :update then attribute_before_last_save(name)
      when :destroy then current
      end

      { 'previous' => previous, 'current' => current }
    end

    def commit_log_exchange_name
      "#{Takamaru.rails_application_name}.#{self.class.takamaru_class_name}"
    end
  end
end
