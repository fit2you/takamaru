namespace :takamaru do
  # The release step should prefer `bundle exec takamaru-declare-queues`, which does not load the application.
  desc 'Declares exchanges, queues and bindings of the consumers of the topology (config/takamaru.yml)'
  task declare_queues: :environment do
    topology = Takamaru.config.topology
    next puts('No Takamaru topology: nothing to declare') if topology.nil?

    channel = Takamaru::RabbitMq::Connection.session.create_channel
    begin
      Takamaru::RabbitMq::Declaration.declare_topology(channel, topology) do |queue_name, exchange_name|
        puts "#{queue_name} bound to #{exchange_name}"
      end
    ensure
      channel.close if channel.open?
    end
  end

  desc 'Checks that the consumer classes match the consumers of the topology (config/takamaru.yml), e.g. in CI'
  task check_topology: :environment do
    Rails.application.eager_load!
    errors = Takamaru::ApplicationConsumer.topology_errors
    abort("Takamaru topology:\n#{errors.map { |error| "- #{error}" }.join("\n")}") if errors.any?

    puts 'Takamaru topology matches the consumers'
  end

  desc 'Runs the relay process: publishes the pending commit logs until INT or TERM'
  task relay: :environment do
    Takamaru::RelayProcess.new.run
  end

  desc 'Publishes the pending commit logs once'
  task relay_once: :environment do
    relay = Takamaru::Relay.new
    loop { break unless relay.publish_batch }
  end

  desc 'Deletes the commit logs published before Takamaru.config.published_retention'
  task cleanup: :environment do
    Takamaru::CommitLogCleanupJob.perform_now
  end
end
