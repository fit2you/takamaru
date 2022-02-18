module RabbitMQ
  class Publisher
    attr_reader :exchange, :channel

    def initialize(exchange_name)
      @exchange_name = exchange_name
      @options = Rails.application.config_for(:rabbit_mq)
    end

    def publish(message)
      ensure_connection
      Rails.logger.debug("[RabbitMQ] Publishing message: #{message} to #{exchange.name}")
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

    def create_bunny_connection
      Bunny.new(hostname: @options.fetch('hostname'))
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
