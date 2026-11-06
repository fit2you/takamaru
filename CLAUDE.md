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
- `Shadowable`: read-only local copy of remote records; host app provides client (`<model>(id)`, `<model>_by(attr, val)`)
  and parser (default `JsonApiParser` → `{ id:, attributes: }`).
- Rake (`lib/tasks/takamaru.rake`): `declare_queues`, `relay`, `relay_once`, `cleanup`. Generators: `install`, `upgrade`.
- Config: `Takamaru.configure`, all options documented in `lib/takamaru/configuration.rb`.

## Decisions (do not revisit without the user)

- Payload is **id-only** + `message_id`, `occurred_at`, `sequence` (= commit log id, monotonic per record). No full
  entity. Delivery at-least-once, unordered: consumers must be idempotent.
- Host apps: 2 Rails projects, Resque (no scheduler) → relay is a dedicated process, not a scheduled job.
- PostgreSQL only; Rails >= 7.0, Ruby >= 3.1; RabbitMQ >= 3.13.
- No HTTP client in the gem; no 0.x compatibility (old jobs/consumers are stopped before release).
- Release: `rails takamaru:declare_queues` after migrations, before starting consumers/relay (fanout drops messages
  with no bound queue).

## Code rules

- Readable code, only public/documented Rails APIs.
- Rubocop (Shopify style) must pass: `bundle exec rubocop`. Use `class << self` for class methods.
- Errors handled without raising go to `Takamaru.report_error(error, context)`.

## Tests

- `bundle exec rspec` on PostgreSQL DB `takamaru_test` (env `POSTGRES_HOST/USER/PASSWORD/TEST_DBNAME`). Schema is
  loaded with `force: true`: **never** point tests at the database of a service.
- Tag `:committed` for specs needing real commits (deletion strategy); RabbitMQ is stubbed with `instance_double`.
