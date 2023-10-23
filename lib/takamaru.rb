require 'app/clients/takamaru/application_client'
require 'app/clients/takamaru/hurricane_client'
require 'app/consumers/takamaru/application_consumer'
require 'app/consumers/takamaru/shadow_model_consumer'
require 'app/jobs/takamaru/commit_log_miner_job'
require 'app/models/takamaru/application_record'
require 'app/models/takamaru/commit_log'
require 'app/models/takamaru/concerns/commit_loggable'
require 'app/models/takamaru/concerns/shadowable'
require 'app/models/takamaru/unhandled_message_log'
require 'rabbit_mq/publisher'
require 'rabbit_mq/queue'
require 'takamaru/errors'
require 'takamaru/version'

module Takamaru
  class << self
    def gem_version
      ::Gem::Version.new(VERSION::STRING)
    end

    def rails_application_name
      klass = Rails.application.class
      # Rails 6.1 introduced `module_parent` method
      (klass.respond_to?(:module_parent) ? klass.module_parent.name : klass.parent_name).underscore
    end
  end
end
