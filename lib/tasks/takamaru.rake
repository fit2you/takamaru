namespace :takamaru do
  desc 'Declares exchanges, queues and bindings of the consumers of the application, without consuming'
  task declare_queues: :environment do
    Rails.application.eager_load!
    Takamaru::ApplicationConsumer.application_consumers.each do |consumer_class|
      queue = consumer_class.new.queue
      queue.declare
      puts "#{queue.name} bound to #{queue.exchange_name}"
    end
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
