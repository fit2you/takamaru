module Takamaru
  class Configuration
    # Prefix of exchange and queue names. Defaults to the application_name of the topology (config/takamaru.yml),
    # then to the underscored module of the Rails application. Setting a different name from the topology raises.
    attr_writer :application_name

    # How often the relay process deletes the commit logs published before published_retention.
    attr_accessor :cleanup_interval

    # Number of unacknowledged messages a consumer receives at once.
    attr_accessor :consumer_prefetch

    # Callable invoked with (error, context) for errors that Takamaru handles without raising.
    attr_accessor :error_handler

    # ActiveJob queue of the relay and cleanup jobs.
    attr_accessor :job_queue

    # How long published commit logs are kept before CommitLogCleanupJob deletes them.
    attr_accessor :published_retention

    # When false the relay leaves commit logs pending: used to pause publishing during broker maintenance.
    attr_accessor :publishing_enabled

    # Bunny connection options. Defaults to config/rabbitmq.yml of the Rails application.
    attr_writer :rabbitmq

    # Commit logs published by each relay run.
    attr_accessor :relay_batch_size

    # Seconds the relay process waits between two rounds.
    attr_accessor :relay_interval

    # Messaging topology, see Takamaru::Topology. Defaults to config/takamaru.yml of the Rails application, nil when
    # the file does not exist (an application without consumers does not need it).
    attr_writer :topology

    # Path of the topology file. Defaults to config/takamaru.yml of the Rails application.
    attr_writer :topology_path

    def initialize
      @cleanup_interval = 1.hour
      @consumer_prefetch = 10
      @error_handler = ->(error, context) { Rails.error.report(error, handled: true, context: context) }
      @job_queue = :takamaru
      @published_retention = 7.days
      @publishing_enabled = ENV.fetch('TAKAMARU_PUBLISHING_ENABLED', 'true') != 'false'
      @relay_batch_size = 100
      @relay_interval = 5
    end

    def application_name
      if topology && @application_name && @application_name != topology.application_name
        raise ConfigurationError,
          "application_name #{@application_name} differs from #{topology.application_name} of the Takamaru topology"
      end

      @application_name || topology&.application_name || Rails.application.class.module_parent_name.underscore
    end

    def topology
      return @topology if defined?(@topology)

      @topology = File.exist?(topology_path) ? Topology.load(topology_path) : nil
    end

    def topology_path
      @topology_path ||= Rails.root.join('config/takamaru.yml')
    end

    def rabbitmq
      @rabbitmq ||= Rails.application.config_for(:rabbitmq)
    end
  end
end
