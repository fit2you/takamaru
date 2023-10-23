module RabbitMq
  class Publisher < Service
    attr_reader :exchange, :channel

    def initialize(exchange_name)
      super
      @exchange_name = exchange_name
    end

    def publish(message)
      ensure_connection
      Rails.logger.debug("[RabbitMq] Publishing message: #{message} to #{exchange.name}")
      exchange.publish(message)
    end

    private

    def bunny
      @bunny ||= create_bunny_connection
    end

    def connect
      bunny.start
      @channel = bunny.create_channel
      @exchange = channel.fanout(@exchange_name)
    end

    def connected?
      bunny&.connected? && channel && exchange
    end

    def ensure_connection
      mutex.synchronize do
        connect unless connected?
      end
    end

    def mutex
      @mutex ||= Mutex.new
    end
  end
end
