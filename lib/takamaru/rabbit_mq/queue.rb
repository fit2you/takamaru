module Takamaru
  module RabbitMq
    # Durable queue "<application name>.<consumer name>" bound to a durable fanout exchange.
    # A message is acknowledged once the subscriber block returns; if the block raises, the message is moved to the
    # dead letter queue "<queue name>.dead".
    class Queue
      attr_reader :exchange_name, :name

      def initialize(exchange_name, consumer_name)
        @exchange_name = exchange_name
        @name = [Takamaru.rails_application_name, consumer_name].join('.')
      end

      def dead_letter_queue_name
        "#{name}.dead"
      end

      # Declares exchange, queue, dead letter queue and binding without consuming (rails takamaru:declare_queues).
      def declare
        channel = Connection.session.create_channel
        declare_on(channel)
      ensure
        channel.close if channel&.open?
      end

      # Blocks until #stop is called or the process receives INT or TERM.
      # The block runs on a Bunny worker thread, one message at a time.
      def subscribe(&block)
        @stopping = false
        channel = Connection.session.create_channel
        channel.prefetch(Takamaru.config.consumer_prefetch)

        consumer = declare_on(channel).subscribe(manual_ack: true) do |delivery_info, _properties, payload|
          process(channel, delivery_info.delivery_tag, payload, &block)
        end

        ShutdownSignals.trap(-> { stop }) { sleep(1) until @stopping }
        consumer.cancel
      ensure
        channel.close if channel&.open?
      end

      def stop
        @stopping = true
      end

      private

      def declare_on(channel)
        exchange = channel.fanout(exchange_name, durable: true)
        channel.queue(dead_letter_queue_name, durable: true)

        # The empty name is the default exchange, which routes a message to the queue named as its routing key.
        queue = channel.queue(name, durable: true, arguments: {
          'x-dead-letter-exchange' => '',
          'x-dead-letter-routing-key' => dead_letter_queue_name,
        })
        queue.bind(exchange)
      end

      def process(channel, delivery_tag, payload)
        yield(payload)
        channel.ack(delivery_tag)
      rescue StandardError => error
        Takamaru.report_error(error, queue: name, payload: payload)
        channel.reject(delivery_tag, false)
      end
    end
  end
end
