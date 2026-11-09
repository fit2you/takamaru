require 'yaml'

module Takamaru
  # Messaging topology of an application, read from config/takamaru.yml: the prefix of its exchanges and queues and
  # the exchange each consumer is bound to.
  #
  #   application_name: hurricane
  #   consumers:
  #     users_consumer: sasori.users   # queue "hurricane.users_consumer" bound to the exchange "sasori.users"
  #
  # It is the only definition of the consumer queues: consumers read their exchange from it, and the queues are
  # declared from it without loading the application (bin/takamaru-declare-queues). Plain Ruby, no Rails.
  class Topology
    attr_reader :application_name, :consumers

    class << self
      def load(path)
        new(YAML.safe_load_file(path) || {})
      rescue Errno::ENOENT
        raise ConfigurationError, "Takamaru topology #{path} not found"
      end
    end

    # consumers: consumer name (the underscored consumer class name, without namespace) => exchange name
    def initialize(document)
      @application_name = document['application_name']
      @consumers = document['consumers'] || {}
      validate!
    end

    def exchange_name_for(consumer_name)
      consumers.fetch(consumer_name) do
        raise ConfigurationError, "Consumer #{consumer_name} is not declared in the Takamaru topology"
      end
    end

    def queue_name_for(consumer_name)
      "#{application_name}.#{consumer_name}"
    end

    private

    def validate!
      unless application_name.is_a?(String) && !application_name.empty?
        raise ConfigurationError, 'Takamaru topology: application_name must be a non empty string'
      end
      unless consumers.is_a?(Hash) && consumers.all? { |name, exchange| name.is_a?(String) && exchange.is_a?(String) }
        raise ConfigurationError, 'Takamaru topology: consumers must map consumer names to exchange names'
      end
    end
  end
end
