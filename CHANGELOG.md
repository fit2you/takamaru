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
- `Takamaru::ShadowClient`: base class describing the client of a shadow model (`find`, `find_by`, `parse`, JSON:API
  by default), and `Takamaru::RemoteRecordNotFound` for missing remote records.
- `takamaru:upgrade` generator for the commit log table created by 0.x.
- Versioned shadow models: with a `remote_updated_at` column (`takamaru:shadow_version` generator), `Shadowable` skips
  responses older than the applied one, under a row lock, so that concurrent jobs cannot restore an older state.
- Messaging topology `config/takamaru.yml` (`Takamaru::Topology`): application name and exchange of each consumer,
  the only definition of the consumer queues.
- `takamaru-declare-queues` executable: declares the consumer queues of the topology before any process starts,
  without loading Rails nor the application (`--environment`, `--env-file`).
- Railtie with the `takamaru:declare_queues`, `takamaru:check_topology`, `takamaru:relay`, `takamaru:relay_once` and
  `takamaru:cleanup` rake tasks. `takamaru:check_topology` (and `Takamaru::ApplicationConsumer.topology_errors`)
  checks that consumer classes and topology match.

### Changed

- Exchanges and queues are durable and messages persistent; publishes wait for the broker confirm.
- Consumers acknowledge a message only after processing it, with configurable prefetch, and shut down gracefully on
  INT and TERM, like the relay process.
- One RabbitMQ connection per process instead of one per published message.
- Commit logs are marked as published instead of being deleted, and keep `attempts` and `last_error`.
- Updates without changes are no longer published.
- `RabbitMq::*` moved to `Takamaru::RabbitMq::*`; `Takamaru::RabbitMq::Queue.new` takes the full queue name.
- Consumers read their exchange from the topology: `Takamaru::ApplicationConsumer#initialize` takes no arguments.
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
