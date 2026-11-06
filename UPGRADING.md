# Upgrading from 0.x to 1.0

1.0 is a breaking release. Phase 1 changes the code of each service; phase 2 is a coordinated rollout across **all**
the services that use Takamaru, because the RabbitMQ topology changes.

## Phase 1: code changes (each service)

1. Bump the gem to `~> 1.0` and run `rails generate takamaru:upgrade && rails db:migrate`. The migration adds
   `message_id`, `published_at`, `attempts`, `last_error` and indexes; rows left by 0.x stay pending and are published
   by 1.0.
2. Consumer jobs receive a third argument: `def perform(id, event, metadata = {})`. Keep the default value: jobs enqueued
   by 0.x consumers still pass two arguments.
3. Remove the `consume_create` / `consume_update` / `consume_destroy` overrides, if any: `ShadowModelConsumer#consume`
   enqueues `<Consumer>Job` directly.
4. `Takamaru::ApplicationClient`, `Takamaru::HurricaneClient` and `Takamaru::RecordNotFound` are gone, together with
   the `httparty` dependency: move the clients into the application (or a dedicated gem). `Shadowable` keeps working
   with any client; see "Shadow models" in the README for clients that do not return JSON:API.
5. Replace `RabbitMq::Publisher` / `RabbitMq::Queue` with `Takamaru::RabbitMq::Publisher` / `Takamaru::RabbitMq::Queue`
   if they are used directly.
6. Rollbar is no longer called: errors go to `Takamaru.config.error_handler`, `Rails.error.report` by default.
7. Add a process running `rails takamaru:relay` (one per service is enough), see the README.
8. Add `rails takamaru:declare_queues` to the release step, right after `rails db:migrate`. It declares the queues and
   bindings of the consumers before any process starts, and it is idempotent: keep it in every release, so that new
   consumers get their queue before publishers can use their exchange.
9. `Takamaru::UnhandledMessageLog` is replaced by the dead letter queues: the `takamaru_unhandled_message_logs` table is
   no longer written and can be dropped once its rows have been reviewed.

## Phase 2: durable exchanges and queues (all services, coordinated)

0.x declared exchanges and queues as non-durable; 1.0 declares them durable, with a dead letter queue. RabbitMQ refuses
to redeclare an existing exchange or queue with different properties (`PRECONDITION_FAILED`), so the old ones have to
be deleted. The outbox makes this lossless: while the job workers are off, events wait in `takamaru_commit_logs`.

1. **Stop the job workers** of every service: nothing is published any more, while web processes keep writing commit
   logs.
2. **Wait until the old queues are empty**, so that the 0.x consumers process what was already published, then
   **stop the 0.x consumers**:
   ```console
   $ rabbitmqctl list_queues name messages consumers
   ```
3. **Delete the old topology**: the non-durable exchanges `<app>.<model>` and queues `<app>.<consumer>` created by
   Takamaru (check the list before deleting, other non-durable objects may not belong to Takamaru):
   ```console
   $ rabbitmqadmin list exchanges name type durable | grep -w False
   $ rabbitmqadmin list queues name durable | grep -w False
   $ rabbitmqadmin delete queue name=<app>.<consumer>
   $ rabbitmqadmin delete exchange name=<app>.<model>
   ```
4. **Deploy 1.0** on every service, keeping job workers, relay processes and consumers off. The release step runs
   `rails db:migrate` and `rails takamaru:declare_queues`, which declares the durable exchanges, the queues with their
   `.dead` queues and the bindings. Delete from the job backend the `Takamaru::CommitLogMinerJob` jobs enqueued by 0.x
   (queue `takamaru`): the class no longer exists and their commit logs are published by the relay anyway.
5. **Check the topology**, once every service has run step 4: in the management UI every queue is bound to its
   exchange. A fanout exchange without bound queues drops what it receives, so this is the only check that matters.
6. **Start consumers, relay processes and job workers**, in any order: the queues already exist, so what is published
   before a consumer starts waits for it. The relay processes publish the accumulated commit logs in order within a few
   seconds.

In the following releases nothing has to be stopped: `rails takamaru:declare_queues` runs before the new processes
start, and relay processes and consumers can be restarted like any other process.

Rolling back to 0.x is possible until step 3, but 0.x has no relay: the commit logs written while the workers were off
would stay unpublished.
