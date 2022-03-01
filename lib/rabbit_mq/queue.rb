module RabbitMQ
  class Queue
    attr_reader :channel, :exchange, :name

    def initialize(exchange_name, consumer_name)
      @exchange_name = exchange_name
      @mutex = Mutex.new
      @name = [Takamaru.rails_application_name, consumer_name].join('.')
      @options = Rails.application.config_for(:rabbit_m_q)
    end

    def subscribe(&block)
      ensure_connection!
      queue = channel.queue(name)
      queue.bind(exchange)
      queue.subscribe(block: true) do |_delivery_info, _properties, payload|
        block.call(payload)
      end
    rescue Interrupt => _e
      channel.close
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
