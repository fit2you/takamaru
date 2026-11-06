module Takamaru
  class Configuration
    # Prefix of exchange and queue names. Defaults to the underscored module of the Rails application.
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
      @application_name ||= Rails.application.class.module_parent_name.underscore
    end

    def rabbitmq
      @rabbitmq ||= Rails.application.config_for(:rabbitmq)
    end
  end
end
