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

Delivery is **at least once** and **not ordered**. A message carries only the id of the record: it is a notification
that the record changed, and the consumer job reads the current state from the owner service (see Shadow models), so
duplicated and out-of-order messages are harmless and the job needs to store neither `message_id` nor `sequence` (they
are there for logs and diagnosis). A remote record not found means it was deleted: the job must not create it again.

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
right before the stop is published again (consumers are idempotent anyway). Other tasks: `rails takamaru:relay_once`
publishes the pending commit logs and exits, `rails takamaru:cleanup` deletes the old published ones; see Consuming
for `takamaru-declare-queues`, `rails takamaru:declare_queues` and `rails takamaru:check_topology`.

Messaging topology, in `config/takamaru.yml`: the prefix of exchanges and queues and, for an application consuming
messages, the exchange of each consumer (see Consuming). It is optional for an application that only publishes.

```yaml
application_name: hurricane
consumers:
  users_consumer: sasori.users # queue "hurricane.users_consumer" bound to the exchange "sasori.users"
```

## Configuration

Every option has a default; set only what you need, e.g. in `config/initializers/takamaru.rb`:

```ruby
Takamaru.configure do |config|
  config.application_name = 'hurricane'           # default: config/takamaru.yml, then the Rails app module
  config.topology_path = 'config/takamaru.yml'    # messaging topology, see Installation
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

```yaml
# config/takamaru.yml
application_name: gordius
consumers:
  users_consumer: hurricane.users # the consumer name is the underscored class name, without namespace
```

```ruby
class UsersConsumer < Takamaru::ShadowModelConsumer
end

class UsersConsumerJob < ApplicationJob
  def perform(id, event, metadata = {})
    # metadata: { 'message_id' => ..., 'occurred_at' => ..., 'sequence' => ... }
  end
end

UsersConsumer.new.consume # blocks until INT or TERM, e.g. in a dedicated process
```

The topology is the only definition of the consumer queues. The consumer reads its exchange from it (a consumer not
declared there raises on start), declares the durable queue `gordius.users_consumer`, binds it to the exchange and
declares the dead letter queue `gordius.users_consumer.dead`.

Declare the queues in the release step, after the migrations and before starting any process, so that nothing
published before a consumer starts is lost: a fanout exchange drops the messages when no queue is bound to it.

```console
$ bundle exec takamaru-declare-queues --environment production --env-file .env.production
```

`takamaru-declare-queues` reads `config/takamaru.yml` and `config/rabbitmq.yml` (ERB, like `config_for`) without
loading Rails nor the application, so it takes a fraction of a second; `--env-file` loads the environment variables
with dotenv, when they are not exported by the shell (variables already set win). Without consumers in the topology it
does not connect to RabbitMQ. `rails takamaru:declare_queues` does the same from the Rails environment.

Check in CI that the consumer classes and the topology match, e.g. with `rails takamaru:check_topology` or a spec:

```ruby
it 'declares every consumer in the Takamaru topology' do
  Rails.application.eager_load!

  expect(Takamaru::ApplicationConsumer.topology_errors).to(eq([]))
end
```

Messages that cannot be parsed or enqueued are reported to the error handler and dead-lettered; they can be moved back
from the RabbitMQ management UI ("Move messages").

## Shadow models

A shadow model is a local, read-only copy of a record owned by another service.

The client belongs to the application: Takamaru does not know how the remote service is reached. Subclass
`Takamaru::ShadowClient` and implement its contract:

```ruby
class UsersShadowClient < Takamaru::ShadowClient
  # Response of the remote record, raises Takamaru::RemoteRecordNotFound when missing
  def find(id)
    HurricaneClient.user(id)
  end

  def find_by(attribute, value)
    HurricaneClient.user_by(attribute, value)
  end

  # Optional: { id:, attributes: } from a response. By default it reads a parsed JSON:API document (a Hash or anything
  # answering to fetch('data'), such as an HTTParty::Response) and underscores the attribute names.
  def parse(response)
    { id: response['uuid'], attributes: response['profile'] }
  end
end

class User < ApplicationRecord
  include Takamaru::Shadowable

  has_shadow_attributes :email, :name
  has_shadow_client UsersShadowClient.new
end

User.find_or_upsert_from_remote!(42)                          # UsersShadowClient#find(42)
User.find_or_upsert_from_remote_by_email!('jane@example.com') # UsersShadowClient#find_by('email', 'jane@example.com')
```

Shadow attributes can only be changed inside `record.allow_shadow_attributes_rewriting { ... }`.

Two jobs of the same record can run concurrently: the one reading the remote record first but saving last would
restore the older state. Add the `remote_updated_at` column to prevent it:

```console
$ rails generate takamaru:shadow_version User && rails db:migrate
```

When the table has it, the shadow model saves there the `updated_at` attribute of the response (the remote record
version) and skips a response older than the saved one, comparing them under a row lock; a response with the same
version is applied again, one without `updated_at` is always applied and keeps the saved version. The owner service
should render `updated_at` with microseconds (`iso8601(6)`): with milliseconds, two changes in the same millisecond
look like the same version.

## Generators

- `takamaru:install` writes, but does not run, the migration creating the commit log table.
- `takamaru:upgrade` writes, but does not run, the migration upgrading the commit log table created by takamaru 0.x.
- `takamaru:shadow_version MODEL` writes, but does not run, the migration adding `remote_updated_at` to the table of a
  shadow model (see Shadow models).

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
