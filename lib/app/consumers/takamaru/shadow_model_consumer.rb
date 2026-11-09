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
  #     # metadata: { 'message_id' => String, 'occurred_at' => String (ISO 8601), 'sequence' => Integer }
  #     def perform(id, event, metadata = {})
  #     end
  #   end
  #
  # Delivery is at least once and not ordered. The message carries only the id: the job reads the current state of the
  # remote record (e.g. Shadowable.upsert_from_remote!), so duplicated and out-of-order messages are harmless and
  # message_id and sequence are only for logs and diagnosis.
  class ShadowModelConsumer < ApplicationConsumer
    EVENTS = %w[create destroy update].freeze
    METADATA = %w[message_id occurred_at sequence].freeze

    def consume
      queue.subscribe { |payload| enqueue_job(JSON.parse(payload)) }
    end

    private

    def enqueue_job(message)
      event = message.fetch('event')
      raise ArgumentError, "Unknown event #{event.inspect}" unless EVENTS.include?(event)

      Takamaru.perform_later!(job_class, message.fetch('id'), event, message.slice(*METADATA))
    end

    def job_class
      "#{self.class.name}Job".constantize
    end
  end
end
