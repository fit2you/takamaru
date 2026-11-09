module Takamaru
  module RabbitMq
    # Publishes persistent messages on durable fanout exchanges and waits for the broker to confirm each of them.
    # Raises Takamaru::PublishError when the broker is unreachable or does not confirm a message, with the original
    # error as cause.
    #
    #   Takamaru::RabbitMq::Publisher.open do |publisher|
    #     publisher.publish('app.users', '{"id":42}', message_id: SecureRandom.uuid, timestamp: Time.current, type: 'update')
    #   end
    class Publisher
      class << self
        def open
          channel = raising_publish_error_on_network_errors do
            Connection.session.create_channel.tap(&:confirm_select)
          end
          yield(new(channel))
        ensure
          channel.close if channel&.open?
        end

        def raising_publish_error_on_network_errors
          yield
        rescue *Connection::NETWORK_ERRORS => error
          raise PublishError, "RabbitMQ unreachable: #{error.class}: #{error.message}"
        end
      end

      def initialize(channel)
        @channel = channel
      end

      def publish(exchange_name, body, message_id:, timestamp:, type:)
        Rails.logger.debug("[Takamaru] Publishing message #{message_id} to #{exchange_name}: #{body}")

        confirmed = self.class.raising_publish_error_on_network_errors do
          exchange = @channel.fanout(exchange_name, durable: true)
          exchange.publish(
            body,
            content_type: 'application/json',
            message_id: message_id,
            persistent: true,
            timestamp: timestamp.to_i,
            type: type,
          )
          @channel.wait_for_confirms
        end

        raise PublishError, "Message #{message_id} not confirmed by #{exchange_name}" unless confirmed
      end
    end
  end
end
