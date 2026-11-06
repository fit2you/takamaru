module Takamaru
  module RabbitMq
    # Declares on a Bunny channel the durable fanout exchange, the durable queue bound to it and its dead letter queue
    # "<queue>.dead", reached through the default exchange. Plain Ruby, no Rails: used by the consumers and by
    # bin/takamaru-declare-queues.
    module Declaration
      class << self
        def declare(channel, exchange_name:, queue_name:)
          exchange = channel.fanout(exchange_name, durable: true)
          channel.queue(dead_letter_queue_name(queue_name), durable: true)

          # The empty name is the default exchange, which routes a message to the queue named as its routing key.
          queue = channel.queue(queue_name, durable: true, arguments: {
            'x-dead-letter-exchange' => '',
            'x-dead-letter-routing-key' => dead_letter_queue_name(queue_name),
          })
          queue.bind(exchange)
        end

        # Declares the queues of all the consumers of the topology, yielding the name of each queue and its exchange.
        def declare_topology(channel, topology)
          topology.consumers.each do |consumer_name, exchange_name|
            queue_name = topology.queue_name_for(consumer_name)
            declare(channel, exchange_name: exchange_name, queue_name: queue_name)
            yield(queue_name, exchange_name) if block_given?
          end
        end

        def dead_letter_queue_name(queue_name)
          "#{queue_name}.dead"
        end
      end
    end
  end
end
