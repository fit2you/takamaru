module RabbitMq
  class Service
    protected

    def initialize
      @rabbit_options = Rails.application.config_for(:rabbitmq)
    end

    def create_bunny_connection
      Bunny.new(
        hostname: @rabbit_options.fetch(:hostname),
        password: @rabbit_options.fetch(:password),
        port: @rabbit_options.fetch(:port),
        username: @rabbit_options.fetch(:username),
        vhost: @rabbit_options.fetch(:vhost),
      )
    end
  end
end
