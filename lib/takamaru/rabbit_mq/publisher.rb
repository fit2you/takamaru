module Takamaru
  module RabbitMq
    # Publishes persistent messages on durable fanout exchanges and waits for the broker to confirm each of them.
    #
    #   Takamaru::RabbitMq::Publisher.open do |publisher|
    #     publisher.publish('app.users', '{"id":42}', message_id: SecureRandom.uuid, timestamp: Time.current, type: 'update')
    #   end
    class Publisher
      class << self
        def open
          channel = Connection.session.create_channel
          channel.confirm_select
          yield(new(channel))
        ensure
          channel.close if channel&.open?
        end
      end

      def initialize(channel)
        @channel = channel
      end

      # Raises Takamaru::PublishError when the broker does not confirm the message.
      def publish(exchange_name, body, message_id:, timestamp:, type:)
        Rails.logger.debug("[Takamaru] Publishing message #{message_id} to #{exchange_name}: #{body}")

        exchange = @channel.fanout(exchange_name, durable: true)
        exchange.publish(
          body,
          content_type: 'application/json',
          message_id: message_id,
          persistent: true,
          timestamp: timestamp.to_i,
          type: type,
        )

        raise PublishError, "Message #{message_id} not confirmed by #{exchange_name}" unless @channel.wait_for_confirms
      end
    end
  end
end
