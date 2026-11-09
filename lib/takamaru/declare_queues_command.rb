require 'optparse'

require 'takamaru/errors'
require 'takamaru/rabbit_mq/connection'
require 'takamaru/rabbit_mq/declaration'
require 'takamaru/rabbit_mq/settings'
require 'takamaru/topology'

module Takamaru
  # takamaru-declare-queues: declares exchanges, queues and bindings of the consumers of config/takamaru.yml, reading
  # the connection from config/rabbitmq.yml, without loading Rails nor the application. Run it in the release step,
  # after the migrations and before starting the processes:
  #
  #   bundle exec takamaru-declare-queues --environment production --env-file .env.production
  #
  # Without consumers in the topology it does not connect to RabbitMQ. Plain Ruby: it must not require 'takamaru'.
  class DeclareQueuesCommand
    def initialize(argv, out: $stdout, err: $stderr)
      @argv = argv
      @err = err
      @out = out
    end

    # Returns the exit status.
    def run
      options = parse_options
      topology = Topology.load(options.fetch(:topology))
      return report('No consumers in the Takamaru topology: nothing to declare') if topology.consumers.empty?

      load_env_files(options.fetch(:env_files))
      declare(topology, RabbitMq::Settings.load(options.fetch(:rabbitmq), options.fetch(:environment)))
      0
    rescue ConfigurationError, OptionParser::ParseError => error
      @err.puts("takamaru-declare-queues: #{error.message}")
      1
    end

    private

    def parse_options
      options = {
        env_files: [],
        environment: ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development',
        rabbitmq: 'config/rabbitmq.yml',
        topology: 'config/takamaru.yml',
      }
      option_parser(options).parse!(@argv.dup)
      options
    end

    def option_parser(options)
      OptionParser.new do |parser|
        parser.banner = 'Usage: takamaru-declare-queues [options]'
        parser.on('--environment NAME', 'Section of the RabbitMQ configuration (default RAILS_ENV)') do |value|
          options[:environment] = value
        end
        parser.on('--env-file PATH', 'Loads environment variables with dotenv (repeatable)') do |value|
          options[:env_files] << value
        end
        parser.on('--rabbitmq PATH', 'RabbitMQ configuration (default config/rabbitmq.yml)') do |value|
          options[:rabbitmq] = value
        end
        parser.on('--topology PATH', 'Takamaru topology (default config/takamaru.yml)') do |value|
          options[:topology] = value
        end
      end
    end

    # Like dotenv-rails, variables already set are not overwritten.
    def load_env_files(paths)
      return if paths.empty?

      begin
        require 'dotenv'
      rescue LoadError
        raise ConfigurationError, '--env-file needs the dotenv gem'
      end
      missing = paths.reject { |path| File.exist?(path) }
      raise ConfigurationError, "env file not found: #{missing.join(', ')}" if missing.any?

      Dotenv.load(*paths)
    end

    def declare(topology, settings)
      session = RabbitMq::Connection.start(settings)
      channel = session.create_channel
      RabbitMq::Declaration.declare_topology(channel, topology) do |queue_name, exchange_name|
        @out.puts("#{queue_name} bound to #{exchange_name}")
      end
    ensure
      session&.close
    end

    def report(message)
      @out.puts(message)
      0
    end
  end
end
