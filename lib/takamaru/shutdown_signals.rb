module Takamaru
  # Lets long-running processes (consumers, relay) stop gracefully on INT and TERM.
  module ShutdownSignals
    SIGNALS = %w[INT TERM].freeze

    class << self
      # Calls on_signal when INT or TERM is received while the block runs, then restores the previous handlers.
      def trap(on_signal)
        previous_handlers = SIGNALS.to_h { |signal| [signal, Signal.trap(signal) { on_signal.call }] }
        yield
      ensure
        previous_handlers&.each { |signal, handler| Signal.trap(signal, handler || 'DEFAULT') }
      end
    end
  end
end
