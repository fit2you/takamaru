# Takamaru

Messaging gem for Sasori microservices: publishes model changes through a **transactional outbox** and consumes them
from RabbitMQ.

Requirements: Ruby >= 3.1, Rails >= 7.0, PostgreSQL >= 9.5, RabbitMQ.

Upgrading from 0.x? Read [UPGRADING.md](UPGRADING.md).

## How it works

```
 model save ──► same DB transaction ──► takamaru_commit_logs (pending)
                                              │
   after commit (job) / relay process ──► Takamaru::Relay ──► durable fanout exchange "<app>.<model>"
                                                                            │
                         durable queue "<consumer app>.<consumer>" ◄────────┘
                                   │                     └──► "<consumer app>.<consumer>.dead" (failed messages)
                                   ▼
                         ShadowModelConsumer ──► "<Consumer>Job".perform_later(id, event, metadata)
```

- The commit log is written in the same transaction of the change: either both are saved or none is.
- The relay publishes pending commit logs in order, waits for the broker confirm and marks them as published. It runs
  in `CommitLogRelayJob`, enqueued after every commit, and in the relay process, which publishes every few seconds what
  the job left behind (failed enqueues, broker outages) and deletes the old published commit logs.
- Messages are persistent, exchanges and queues durable: they survive a broker restart.
- A consumer acknowledges a message only after its job has been enqueued; failures go to the dead letter queue.

Delivery is **at least once** and **not ordered**: consumers must be idempotent (use `message_id`) and may discard
stale events (use `sequence`, which grows for each change of the same record).

## Installation

```ruby
# Gemfile
gem 'takamaru', '~> 1.0'
```

```console
$ rails generate takamaru:install
$ rails db:migrate
```

RabbitMQ connection, in `config/rabbitmq.yml`:

```yaml
default: &default
  hostname: <%= ENV.fetch('RABBITMQ_HOSTNAME') %>
  port: <%= ENV.fetch('RABBITMQ_PORT', 5672) %>
  username: <%= ENV.fetch('RABBITMQ_USERNAME') %>
  password: <%= ENV.fetch('RABBITMQ_PASSWORD') %>
  vhost: <%= ENV.fetch('RABBITMQ_VHOST', '/') %>

development:
  <<: *default
production:
  <<: *default
```

Run the relay process next to web, workers and consumers; no job scheduler is needed:

```console
$ rails takamaru:relay # runs until INT or TERM, completing the current batch
```

Several replicas can run at the same time, and deploys can restart it at any moment: at worst a commit log published
right before the stop is published again (consumers are idempotent anyway). Other tasks: `rails takamaru:declare_queues` (see Consuming), `rails takamaru:relay_once`
publishes the pending commit logs and exits, `rails takamaru:cleanup` deletes the old published ones.

## Configuration

Every option has a default; set only what you need, e.g. in `config/initializers/takamaru.rb`:

```ruby
Takamaru.configure do |config|
  config.application_name = 'hurricane'           # prefix of exchanges and queues, default: Rails app module
  config.cleanup_interval = 1.hour                # how often the relay process deletes old published commit logs
  config.consumer_prefetch = 10                   # unacknowledged messages per consumer
  config.error_handler = ->(error, context) { Rails.error.report(error, handled: true, context: context) }
  config.job_queue = :takamaru                    # ActiveJob queue of CommitLogRelayJob
  config.published_retention = 7.days             # published commit logs kept for audit
  config.publishing_enabled = true                # ENV TAKAMARU_PUBLISHING_ENABLED=false pauses the relay
  config.rabbitmq = { hostname: 'rabbitmq', ... } # default: config/rabbitmq.yml
  config.relay_batch_size = 100
  config.relay_interval = 5                       # seconds between two rounds of the relay process
end
```

## Publishing

```ruby
class User < ApplicationRecord
  include Takamaru::CommitLoggable

  # optional, the exchange is "<application name>.users" by default
  override_takamaru_class_name 'customers'
end

user.without_commit_log { |u| u.update!(name: 'Jane') } # this change is not published
```

Each create, destroy and update (with changes) publishes:

```json
{
  "event": "update",
  "id": 42,
  "message_id": "6b0e5f0e-8a4f-4d8e-9a7c-3c1f0b7f5b1e",
  "occurred_at": "2026-11-03T10:00:00.000000Z",
  "sequence": 1234
}
```

Changes that skip Active Record callbacks (`update_columns`, `update_all`, `delete`, `delete_all`, `insert_all`,
`upsert_all`) are **not** published.

## Consuming

```ruby
class UsersConsumer < Takamaru::ShadowModelConsumer
  def initialize
    super('hurricane.users') # exchange to consume
  end
end

class UsersConsumerJob < ApplicationJob
  def perform(id, event, metadata = {})
    # metadata: { 'message_id' => ..., 'occurred_at' => ..., 'sequence' => ... }
  end
end

UsersConsumer.new.consume # blocks until INT or TERM, e.g. in a dedicated process
```

The consumer declares the durable queue `<application name>.users_consumer`, binds it to the exchange and declares the
dead letter queue `<application name>.users_consumer.dead`. Run `rails takamaru:declare_queues` in the release step,
after the migrations: it declares the queues of all the consumers of the application (subclasses of
`Takamaru::ApplicationConsumer`, instantiable without arguments) without consuming, so that nothing published before a
consumer starts is lost: a fanout exchange drops the messages when no queue is bound to it. Messages that cannot be parsed or enqueued are reported to
the error handler and dead-lettered; they can be moved back from the RabbitMQ management UI ("Move messages").

## Shadow models

A shadow model is a local, read-only copy of a record owned by another service.

```ruby
class User < ApplicationRecord
  include Takamaru::Shadowable

  has_shadow_attributes :email, :name
  has_shadow_client UsersClient
end

User.find_or_upsert_from_remote!(42)                          # UsersClient.user(42)
User.find_or_upsert_from_remote_by_email!('jane@example.com') # UsersClient.user_by('email', 'jane@example.com')
```

The client belongs to the application: Takamaru only calls `<model>(id)` and `<model>_by(attribute, value)` and hands the
result to a parser. The default parser, `Takamaru::JsonApiParser`, reads a parsed JSON:API document (a Hash or anything
answering to `fetch('data')`, such as an `HTTParty::Response`). Any other format needs a parser returning
`{ id:, attributes: }`:

```ruby
has_shadow_client UsersClient, parser: ->(response) { { id: response['uuid'], attributes: response['profile'] } }
```

Shadow attributes can only be changed inside `record.allow_shadow_attributes_rewriting { ... }`.

## Generators

- `takamaru:install` writes, but does not run, the migration creating the commit log table.
- `takamaru:upgrade` writes, but does not run, the migration upgrading the commit log table created by takamaru 0.x.

## Initial config

**:warning: Please, run the following steps the first time you pull this repository.**

- This workspace has **extension reccomendations** for Visual Studio Code; please, install all of them at the first run.
- Also, open the folder `/workspace/takamaru` at the first run.
- Tell `git` where to find the project shared hooks: `git config core.hooksPath .githooks`.
- Tell `git flow` where to find the project shared hooks: `git config gitflow.path.hooks .githooks`.
- Then setup git flow with the following command: `git flow init -f -d --bugfix bugfix/ --feature feature/ --hotfix hotfix/ --release release/ --support support/ --tag ''`.
- Run `bundle` to install all the gems.

## Tests

The suite runs on PostgreSQL, in a dedicated `takamaru_test` database created on the first run (it loads its schema with
`force: true` and truncates the tables: never point it to the database of a service). Connection settings come from
`POSTGRES_HOST`, `POSTGRES_USER`, `POSTGRES_PASSWORD` and `POSTGRES_TEST_DBNAME`, with defaults matching the devcontainer.

```console
$ bundle exec rspec
```

## Code Style

[Rubocop](https://github.com/rubocop/rubocop) gem is enabled by default in `devcontainer` and will automatically format
files on save and check all the project before commit.

[Ruby Style Guide](https://github.com/Shopify/ruby-style-guide) gem is the source for our style guide. We changed just
a little of config in the `.rubocop.yml` file.

## Code quality

To run all the quality checks together use the this command:

```console
$ rails code_quality:check
```

[RubyCritic](https://github.com/whitesmith/rubycritic) gem should be used from `cli` to generate `html` report in
`/tmp/rubycritic`. Simply run the command `rubycritic` from workspace root path.

[Bundler audit](https://github.com/rubysec/bundler-audit) gem should be used from `cli` to generate a `json` report in
`/tmp/bundler-audit.json`. Simply run the command `bundle-audit` from workspace root path.
