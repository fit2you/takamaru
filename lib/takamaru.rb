require 'active_job'
require 'active_record'
require 'bunny'
require 'rails'

require 'takamaru/configuration'
require 'takamaru/errors'
require 'takamaru/json_api_parser'
require 'takamaru/rabbit_mq/connection'
require 'takamaru/rabbit_mq/declaration'
require 'takamaru/rabbit_mq/publisher'
require 'takamaru/rabbit_mq/queue'
require 'takamaru/relay'
require 'takamaru/relay_process'
require 'takamaru/shadow_client'
require 'takamaru/shutdown_signals'
require 'takamaru/topology'
require 'takamaru/version'

require 'app/consumers/takamaru/application_consumer'
require 'app/consumers/takamaru/shadow_model_consumer'
require 'app/jobs/takamaru/commit_log_cleanup_job'
require 'app/jobs/takamaru/commit_log_relay_job'
require 'app/models/takamaru/application_record'
require 'app/models/takamaru/commit_log'
require 'app/models/takamaru/concerns/commit_loggable'
require 'app/models/takamaru/concerns/shadowable'

require 'takamaru/railtie'

module Takamaru
  class << self
    def config
      @config ||= Configuration.new
    end

    # Takamaru.configure do |config|
    #   config.relay_batch_size = 500
    # end
    def configure
      yield(config)
    end

    def gem_version
      ::Gem::Version.new(VERSION::STRING)
    end

    def rails_application_name
      config.application_name
    end

    def report_error(error, context = {})
      config.error_handler.call(error, context)
    end

    # Like job_class.perform_later, but raises Takamaru::EnqueueError, with the original error as cause, when the job
    # backend does not enqueue the job (e.g. Redis is unreachable) instead of raising its own errors or returning false.
    def perform_later!(job_class, *arguments)
      enqueued = begin
        job_class.perform_later(*arguments)
      rescue StandardError => error
        raise EnqueueError, "#{job_class.name} not enqueued: #{error.class}: #{error.message}"
      end
      raise EnqueueError, "#{job_class.name} not enqueued" unless enqueued
    end
  end
end
