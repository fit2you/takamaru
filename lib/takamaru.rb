require 'app/clients/application_client'
require 'app/clients/hurricane_client'
require 'app/jobs/takamaru/commit_log_miner_job'
require 'app/models/takamaru/commit_log'
require 'app/models/takamaru/concerns/commit_loggable'
require 'rabbit_mq/publisher'
require 'takamaru/version'

module Takamaru
  class << self
    def gem_version
      ::Gem::Version.new(VERSION::STRING)
    end
  end
end
