module RabbitMq
  class RabbitService
    protected

    def initialize
      @rabbit_options = Rails.application.config_for(:rabbitmq)
    end

    def create_bunny_connection
      Bunny.new(hostname: @rabbit_options.fetch(:hostname), vhost: @rabbit_options.fetch(:vhost))
    end
  end
end
