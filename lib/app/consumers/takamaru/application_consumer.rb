module Takamaru
  class ApplicationConsumer
    class << self
      # The consumers defined by the application: every subclass except the base classes provided by Takamaru.
      # Each of them must be instantiable without arguments.
      def application_consumers
        descendants.reject { |consumer_class| consumer_class.name.start_with?('Takamaru::') }
      end
    end

    attr_reader :queue

    def initialize(exchange_name)
      @queue = RabbitMq::Queue.new(exchange_name, self.class.name.demodulize.underscore)
    end

    def stop
      queue.stop
    end
  end
end
