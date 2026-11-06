module Takamaru
  # Outbox row: an event written in the same transaction of the change that generated it, published later by
  # CommitLogRelayJob.
  class CommitLog < ApplicationRecord
    attribute :message_id, default: -> { SecureRandom.uuid }

    scope :pending, -> { where(published_at: nil) }
    scope :published_before, ->(time) { where(published_at: ...time) }

    validates :exchange_name, presence: true
    validates :message_id, presence: true
    validates :payload, presence: true

    # The payload enriched with delivery metadata. The id is used as sequence: commit logs of the same record are
    # written while holding the record's row lock, so their ids grow in commit order.
    def message
      payload.merge(
        'message_id' => message_id,
        'occurred_at' => created_at.utc.iso8601(6),
        'sequence' => id,
      )
    end

    def mark_as_published!
      update!(published_at: Time.current)
    end

    def record_failure!(error)
      update!(attempts: attempts + 1, last_error: "#{error.class}: #{error.message}")
    end
  end
end
