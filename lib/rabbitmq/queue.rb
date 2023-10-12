module Rabbitmq
  class Queue
    attr_reader :channel, :exchange, :exchange_name, :name

    def initialize(exchange_name, consumer_name)
      @exchange_name = exchange_name
      @mutex = Mutex.new
      @name = [Takamaru.rails_application_name, consumer_name].join('.')
      @options = Rails.application.config_for(:rabbitmq)
    end

    def subscribe(&block)
      ensure_connection!
      queue = channel.queue(name)
      queue.bind(exchange)
      queue.subscribe(block: true) do |_delivery_info, _properties, payload|
        yield(payload)
      end
    rescue Interrupt => _e
      channel.close
      sleep(2) # NOTE: that should be a safe amount to ensure the yield submitting work
    end

    private

    def connect!
      @bunny ||= create_bunny_connection
      @bunny.start
      @channel = @bunny.create_channel
      @exchange = channel.fanout(@exchange_name)
    end

    def connected?
      @bunny&.connected? && channel && exchange
    end

    def create_bunny_connection
      Bunny.new(hostname: @options.fetch(:hostname))
    end

    def ensure_connection!
      @mutex.synchronize do
        connect! unless connected?
      end
    end
  end
end
