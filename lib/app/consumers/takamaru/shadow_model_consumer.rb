module Takamaru
  # Enqueues "<consumer class name>Job" for every message published by a CommitLoggable model:
  #
  #   # config/takamaru.yml
  #   consumers:
  #     users_consumer: hurricane.users
  #
  #   class UsersConsumer < Takamaru::ShadowModelConsumer
  #   end
  #
  #   class UsersConsumerJob < ApplicationJob
  #     # metadata: { 'message_id' => String, 'occurred_at' => String (ISO 8601), 'sequence' => Integer }, plus
  #     # 'attributes' => { name => { 'previous' => ..., 'current' => ... } } when the model declares commit_log_attributes
  #     def perform(id, event, metadata = {})
  #     end
  #   end
  #
  # A consumer interested in some records only skips the others, without enqueuing their job, by overriding accept?,
  # called for the messages carrying attributes (those without are always accepted, e.g. published before the model
  # declared them):
  #
  #   class DealersConsumer < Takamaru::ShadowModelConsumer
  #     private
  #
  #     def accept?(message)
  #       attribute_values(message, 'role').intersect?(%w[dealer branch])
  #     end
  #   end
  #
  # Delivery is at least once and not ordered. The message carries only the id: the job reads the current state of the
  # remote record (e.g. Shadowable.upsert_from_remote!), so duplicated and out-of-order messages are harmless and
  # message_id and sequence are only for logs and diagnosis.
  class ShadowModelConsumer < ApplicationConsumer
    EVENTS = %w[create destroy update].freeze
    METADATA = %w[attributes message_id occurred_at sequence].freeze

    def consume
      queue.subscribe { |payload| enqueue_job(JSON.parse(payload)) }
    end

    private

    def enqueue_job(message)
      event = message.fetch('event')
      raise ArgumentError, "Unknown event #{event.inspect}" unless EVENTS.include?(event)
      return if message.key?('attributes') && !accept?(message)

      Takamaru.perform_later!(job_class, message.fetch('id'), event, message.slice(*METADATA))
    end

    # Overridden to skip messages by their attributes (see CommitLoggable.commit_log_attributes): a skipped message is
    # acknowledged and its job is not enqueued.
    def accept?(_message)
      true
    end

    # Previous and current values of an attribute of the message, without nils and duplicates (e.g. ['vendor',
    # 'dealer'] for a vendor that became a dealer, ['dealer'] for a dealer); [] when the message does not carry it.
    def attribute_values(message, name)
      values = message.dig('attributes', name)
      return [] unless values.is_a?(Hash)

      values.values_at('previous', 'current').compact.uniq
    end

    def job_class
      "#{self.class.name}Job".constantize
    end
  end
end
