require 'bunny'

module Takamaru
  module RabbitMq
    # One Bunny session per process, opened lazily and shared by all threads.
    # Bunny sessions are thread-safe while channels are not: every unit of work opens and closes its own channel.
    module Connection
      # Errors of an unreachable or restarting broker, which go away by themselves. Configuration errors, such as a
      # wrong password or an exchange redeclared with different properties, are not among them.
      NETWORK_ERRORS = [
        Bunny::ChannelAlreadyClosed,
        Bunny::ConnectionAlreadyClosed,
        Bunny::ConnectionClosedError,
        Bunny::ConnectionForced,
        Bunny::HostListDepleted,
        Bunny::NetworkErrorWrapper,
        Bunny::NetworkFailure,
        Bunny::TCPConnectionFailed,
        SystemCallError,
        Timeout::Error,
      ].freeze

      @mutex = Mutex.new

      class << self
        def session
          @mutex.synchronize do
            forget_session_inherited_from_parent_process
            @session = open_session unless @session&.open?
            @session
          end
        end

        # Opens a new Bunny session, not shared, with the given options (hostname, port, username, password, vhost).
        def start(options)
          Bunny.new(
            hostname: options.fetch(:hostname),
            password: options.fetch(:password),
            port: options.fetch(:port),
            username: options.fetch(:username),
            vhost: options.fetch(:vhost, '/'),
          ).tap(&:start)
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
          start(Takamaru.config.rabbitmq)
        end
      end
    end
  end
end
