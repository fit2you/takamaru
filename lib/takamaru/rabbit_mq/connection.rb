module Takamaru
  module RabbitMq
    # One Bunny session per process, opened lazily and shared by all threads.
    # Bunny sessions are thread-safe while channels are not: every unit of work opens and closes its own channel.
    module Connection
      @mutex = Mutex.new

      class << self
        def session
          @mutex.synchronize do
            forget_session_inherited_from_parent_process
            @session = open_session unless @session&.open?
            @session
          end
        end

        def close
          @mutex.synchronize do
            @session.close if @session&.open?
            @session = nil
          end
        end

        private

        # After a fork the session belongs to the parent process (it shares its socket): the child must open its own.
        def forget_session_inherited_from_parent_process
          return if @pid == Process.pid

          @pid = Process.pid
          @session = nil
        end

        def open_session
          options = Takamaru.config.rabbitmq

          Bunny.new(
            hostname: options.fetch(:hostname),
            password: options.fetch(:password),
            port: options.fetch(:port),
            username: options.fetch(:username),
            vhost: options.fetch(:vhost, '/'),
          ).tap(&:start)
        end
      end
    end
  end
end
