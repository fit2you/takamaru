require 'rails_helper'
require 'takamaru/rabbit_mq/settings'

RSpec.describe(Takamaru::RabbitMq::Settings) do
  def with_file(content)
    Tempfile.create(['rabbitmq', '.yml']) do |file|
      file.write(content)
      file.close
      yield(file.path)
    end
  end

  it 'reads the section of the environment with ERB and aliases, like config_for' do
    content = <<~YAML
      default: &default
        hostname: <%= 'rabbit' + 'mq' %>
        port: 5672
      production:
        <<: *default
        vhost: sasori
    YAML

    with_file(content) do |path|
      expect(described_class.load(path, 'production')).to(eq(hostname: 'rabbitmq', port: 5672, vhost: 'sasori'))
    end
  end

  it 'merges the shared section' do
    with_file("shared:\n  port: 5672\nproduction:\n  hostname: rabbitmq\n") do |path|
      expect(described_class.load(path, 'production')).to(eq(port: 5672, hostname: 'rabbitmq'))
    end
  end

  it 'raises when the environment has no section' do
    with_file("development:\n  hostname: localhost\n") do |path|
      expect { described_class.load(path, 'production') }
        .to(raise_error(Takamaru::ConfigurationError, "#{path} has no production section"))
    end
  end

  it 'raises when an environment variable is missing' do
    with_file("production:\n  hostname: <%= ENV.fetch('TAKAMARU_SPEC_MISSING') %>\n") do |path|
      expect { described_class.load(path, 'production') }.to(raise_error(
        Takamaru::ConfigurationError,
        "#{path}: missing environment variable TAKAMARU_SPEC_MISSING (see --env-file)",
      ))
    end
  end

  it 'raises when the file does not exist' do
    expect { described_class.load('missing.yml', 'production') }
      .to(raise_error(Takamaru::ConfigurationError, 'RabbitMQ configuration missing.yml not found'))
  end
end
