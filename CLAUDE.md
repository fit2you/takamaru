# Takamaru

Rails gem: transactional outbox → RabbitMQ (Bunny), plus consumers and shadow models. User docs: README.md; 0.x→1.0
migration: UPGRADING.md.

## Architecture

- `CommitLoggable` (model concern): create/update(with changes)/destroy write a `Takamaru::CommitLog` in the same
  transaction; `after_commit` enqueues `CommitLogRelayJob`.
- `Relay#publish_batch`: locks pending rows (`FOR UPDATE SKIP LOCKED`, order by id), publishes with publisher confirms,
  marks published; stops at first failure (`record_failure!`) to keep order. Returns true if the batch was full.
- `RelayProcess` (`rails takamaru:relay`): loop relay + periodic `CommitLogCleanupJob`, graceful INT/TERM.
- `RabbitMq::Connection`: one Bunny session per process, fork-safe (pid check). `Publisher`: channel with confirms.
  `Queue`: durable fanout exchange `<publisher app>.<model>`, durable queue `<app>.<consumer>`, DLQ `<queue>.dead` via
  default exchange; manual ack, prefetch, reject→DLQ on error.
- `ShadowModelConsumer`: parses message, enqueues `"<Consumer>Job".perform_later(id, event, metadata)`.
- `Shadowable`: read-only local copy of remote records via a host-app `ShadowClient` subclass (`find(id)`,
  `find_by(attr, val)`, raise `RemoteRecordNotFound`; `parse` → `{ id:, attributes: }`, default `JsonApiParser`).
  Optional `remote_updated_at` column (generator `shadow_version`): saves the response `updated_at`, skips older ones
  under `lock!`, in a savepoint (RecordNotUnique retry works inside outer transactions).
- `Topology` (`config/takamaru.yml`): application name + `consumer name => exchange`, the only definition of consumer
  queues; `ApplicationConsumer#initialize` (no args) reads it. `RabbitMq::Declaration` declares exchange/queue/DLQ.
- `exe/takamaru-declare-queues` (`DeclareQueuesCommand`): declares the topology queues **without Rails** (plain Ruby:
  `topology`, `rabbit_mq/settings` reads rabbitmq.yml like config_for, `connection`, `declaration`; never require
  `takamaru` there, a spec checks Rails/ActiveSupport are not loaded). `--env-file` uses dotenv if available.
- Rake (`lib/tasks/takamaru.rake`): `declare_queues`, `check_topology`, `relay`, `relay_once`, `cleanup`. Generators:
  `install`, `upgrade`, `shadow_version`.
- Config: `Takamaru.configure`, all options documented in `lib/takamaru/configuration.rb`.

## Decisions (do not revisit without the user)

- Payload is **id-only** + `message_id`, `occurred_at`, `sequence` (= commit log id, monotonic per record). No full
  entity. Delivery at-least-once, unordered: the job re-reads the current state, so duplicates/disorder are harmless
  and consumers need no inbox (`message_id`/`sequence` only for diagnosis); concurrency guarded by `remote_updated_at`.
- Host apps: 2 Rails projects, Resque (no scheduler) → relay is a dedicated process, not a scheduled job.
- PostgreSQL only; Rails >= 7.0, Ruby >= 3.1; RabbitMQ >= 3.13.
- No HTTP client in the gem; no 0.x compatibility (old jobs/consumers are stopped before release).
- Release: `bundle exec takamaru-declare-queues` after migrations, before starting consumers/relay (fanout drops
  messages with no bound queue). Topology in a YAML file, not discovered from consumer classes (that needs eager load).

## Code rules

- Readable code, only public/documented Rails APIs.
- Rubocop (Shopify style) must pass: `bundle exec rubocop`. Use `class << self` for class methods.
- Errors handled without raising go to `Takamaru.report_error(error, context)`. Transient failures are wrapped (cause
  kept) in `TransientError` subclasses, one per kind, because Rollbar groups by class: `PublishError` (broker, see
  `Connection::NETWORK_ERRORS`; config errors like `PreconditionFailed` stay raw), `EnqueueError`
  (`Takamaru.perform_later!`).

## Tests

- `bundle exec rspec` on PostgreSQL DB `takamaru_test` (env `POSTGRES_HOST/USER/PASSWORD/TEST_DBNAME`). Schema is
  loaded with `force: true`: **never** point tests at the database of a service.
- Tag `:committed` for specs needing real commits (deletion strategy); RabbitMQ is stubbed with `instance_double`.
