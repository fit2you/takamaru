require 'erb'
require 'yaml'

module Takamaru
  module RabbitMq
    # Reads the Bunny connection options of an environment from config/rabbitmq.yml, like Rails' config_for (ERB,
    # aliases, optional "shared" section) but without Rails: used by takamaru-declare-queues.
    module Settings
      class << self
        def load(path, environment)
          document = YAML.safe_load(evaluate(path), aliases: true) || {}
          unless document.key?(environment)
            raise ConfigurationError, "#{path} has no #{environment} section"
          end

          (document['shared'] || {}).merge(document.fetch(environment) || {}).transform_keys(&:to_sym)
        end

        private

        # ERB of the whole file, as Rails does: every section needs its ENV.fetch variables.
        def evaluate(path)
          ERB.new(File.read(path)).result
        rescue Errno::ENOENT
          raise ConfigurationError, "RabbitMQ configuration #{path} not found"
        rescue KeyError => error
          raise ConfigurationError, "#{path}: missing environment variable #{error.key} (see --env-file)"
        end
      end
    end
  end
end
