module Takamaru
  # Base of the consumers: the queue and the exchange of a consumer come from the topology (config/takamaru.yml),
  # where it is declared by name (see .consumer_name).
  class ApplicationConsumer
    class << self
      # The consumers defined by the application: every subclass except the base classes provided by Takamaru.
      def application_consumers
        descendants.reject { |consumer_class| consumer_class.name.start_with?('Takamaru::') }
      end

      # Name of the consumer in the topology and in its queue: the underscored class name, without namespace.
      def consumer_name
        name.demodulize.underscore
      end

      # Differences between the consumer classes and the topology; empty when they match. The application must be
      # eager loaded, otherwise the consumers not loaded yet are missing (see rails takamaru:check_topology).
      def topology_errors
        declared = Takamaru.config.topology&.consumers&.keys || []
        names = application_consumers.map(&:consumer_name)

        errors = (names - declared).map { |name| "consumer #{name} is not declared in the topology" }
        errors += (declared - names).map { |name| "the topology declares #{name}, which has no consumer class" }
        errors + names.tally.select { |_name, count| count > 1 }.keys.map { |name| "more consumers are named #{name}" }
      end
    end

    attr_reader :queue

    def initialize
      topology = Takamaru.config.topology
      raise ConfigurationError, "#{Takamaru.config.topology_path} is required by the consumers" if topology.nil?

      consumer_name = self.class.consumer_name
      @queue = RabbitMq::Queue.new(topology.exchange_name_for(consumer_name), topology.queue_name_for(consumer_name))
    end

    def stop
      queue.stop
    end
  end
end
