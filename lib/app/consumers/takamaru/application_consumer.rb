module Takamaru
  class ApplicationConsumer
    attr_reader :queue

    def initialize(exchange_name)
      @queue = RabbitMq::Queue.new(exchange_name, self.class.name.split('::').last.underscore)
    end
  end
end
