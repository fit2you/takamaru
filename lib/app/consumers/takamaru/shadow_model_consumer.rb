module Takamaru
  # Enqueues "<consumer class name>Job" for every message published by a CommitLoggable model:
  #
  #   class UsersConsumer < Takamaru::ShadowModelConsumer
  #     def initialize
  #       super('hurricane.users')
  #     end
  #   end
  #
  #   class UsersConsumerJob < ApplicationJob
  #     # metadata: { 'message_id' => String, 'occurred_at' => String (ISO 8601), 'sequence' => Integer }
  #     def perform(id, event, metadata = {})
  #     end
  #   end
  #
  # Delivery is at least once and not ordered: jobs must be idempotent (message_id) and may discard stale events
  # (a lower sequence than the last one applied to the same id).
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

      job_class.perform_later(message.fetch('id'), event, message.slice(*METADATA))
    end

    def job_class
      "#{self.class.name}Job".constantize
    end
  end
end
