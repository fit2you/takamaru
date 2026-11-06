# Changelog

## 1.0.0

Breaking release, see [UPGRADING.md](UPGRADING.md).

### Added

- `Takamaru::Relay`: publishes the pending commit logs in order, with `FOR UPDATE SKIP LOCKED` to run safely in
  parallel. It runs in `Takamaru::CommitLogRelayJob`, enqueued after every commit, and in the relay process
  (`rails takamaru:relay`), which catches up what the job left behind without a job scheduler.
- `Takamaru::CommitLogCleanupJob`: deletes published commit logs after `published_retention`, run by the relay process
  every `cleanup_interval` (`rails takamaru:cleanup`).
- `Takamaru.configure`, with a configurable error handler (`Rails.error.report` by default) and
  `TAKAMARU_PUBLISHING_ENABLED` to pause publishing.
- Message metadata: `message_id`, `occurred_at`, `sequence`, passed to consumer jobs as third argument.
- Dead letter queue `<queue>.dead` for each consumer queue.
- `Shadowable` accepts a `parser:` for the client responses (default `Takamaru::JsonApiParser`).
- `takamaru:upgrade` generator for the commit log table created by 0.x.
- Railtie with the `takamaru:declare_queues`, `takamaru:relay`, `takamaru:relay_once` and `takamaru:cleanup` rake
  tasks. `takamaru:declare_queues` declares the consumer queues before any process starts.

### Changed

- Exchanges and queues are durable and messages persistent; publishes wait for the broker confirm.
- Consumers acknowledge a message only after processing it, with configurable prefetch, and shut down gracefully on
  INT and TERM, like the relay process.
- One RabbitMQ connection per process instead of one per published message.
- Commit logs are marked as published instead of being deleted, and keep `attempts` and `last_error`.
- Updates without changes are no longer published.
- `RabbitMq::*` moved to `Takamaru::RabbitMq::*`.
- Requires Ruby >= 3.1, Rails >= 7.0 (Rails 8 supported), PostgreSQL.

### Fixed

- Only the last commit log of a transaction was published; a stale or missing id was enqueued after rollbacks or
  `without_commit_log`.
- `without_commit_log` and `allow_shadow_attributes_rewriting` left their flag set when the block raised.
- `override_takamaru_class_name` changed the exchange of the whole class hierarchy.
- Dynamic finders of `Shadowable` failed on attributes containing underscores.
- Concurrent upserts of the same shadow record raised `ActiveRecord::RecordNotUnique`.
- Arbitrary `consume_*` methods could be invoked through the message `event`.

### Removed

- `Takamaru::ApplicationClient`, `Takamaru::HurricaneClient`, `Takamaru::RecordNotFound` and the `httparty` dependency.
- `Takamaru::UnhandledMessageLog`, replaced by dead letter queues.
- Rollbar calls.
- `Takamaru::CommitLogMinerJob`, replaced by `Takamaru::CommitLogRelayJob`.
