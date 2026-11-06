require 'open3'
require 'rails_helper'
require 'takamaru/declare_queues_command'

RSpec.describe(Takamaru::DeclareQueuesCommand) do
  let(:bunny_queue) { instance_double(Bunny::Queue) }
  let(:channel) { instance_double(Bunny::Channel, fanout: exchange) }
  let(:dir) { Dir.mktmpdir }
  let(:err) { StringIO.new }
  let(:exchange) { instance_double(Bunny::Exchange) }
  let(:out) { StringIO.new }
  let(:session) { instance_double(Bunny::Session, close: nil, create_channel: channel) }

  before do
    allow(Takamaru::RabbitMq::Connection).to(receive(:start).and_return(session))
    allow(channel).to(receive(:queue).and_return(bunny_queue))
    allow(bunny_queue).to(receive(:bind).and_return(bunny_queue))
    write('takamaru.yml', "application_name: hurricane\nconsumers:\n  users_consumer: sasori.users\n")
    write('rabbitmq.yml', <<~YAML)
      production:
        hostname: <%= ENV.fetch('TAKAMARU_SPEC_RABBITMQ_HOSTNAME', 'rabbitmq') %>
        port: 5672
    YAML
  end

  after do
    FileUtils.remove_entry(dir)
    ENV.delete('TAKAMARU_SPEC_RABBITMQ_HOSTNAME')
  end

  def write(name, content)
    File.write(File.join(dir, name), content)
  end

  def run(*args)
    described_class.new(
      ['--topology', "#{dir}/takamaru.yml", '--rabbitmq', "#{dir}/rabbitmq.yml", *args],
      out: out,
      err: err,
    ).run
  end

  it 'declares the queues of the topology with the connection of the environment' do
    expect(run('--environment', 'production')).to(eq(0))

    expect(Takamaru::RabbitMq::Connection).to(have_received(:start).with(hostname: 'rabbitmq', port: 5672))
    expect(channel).to(have_received(:queue).with('hurricane.users_consumer', durable: true, arguments: anything))
    expect(out.string).to(eq("hurricane.users_consumer bound to sasori.users\n"))
    expect(session).to(have_received(:close))
  end

  it 'loads the env files before reading the connection' do
    write('.env.production', "TAKAMARU_SPEC_RABBITMQ_HOSTNAME=from-env-file\n")

    run('--environment', 'production', '--env-file', "#{dir}/.env.production")

    expect(Takamaru::RabbitMq::Connection).to(have_received(:start).with(hostname: 'from-env-file', port: 5672))
  end

  it 'does not overwrite variables already set with the env files' do
    ENV['TAKAMARU_SPEC_RABBITMQ_HOSTNAME'] = 'from-environment'
    write('.env.production', "TAKAMARU_SPEC_RABBITMQ_HOSTNAME=from-env-file\n")

    run('--environment', 'production', '--env-file', "#{dir}/.env.production")

    expect(Takamaru::RabbitMq::Connection).to(have_received(:start).with(hostname: 'from-environment', port: 5672))
  end

  it 'does not connect without consumers' do
    write('takamaru.yml', "application_name: hurricane\n")

    expect(run('--environment', 'production')).to(eq(0))

    expect(out.string).to(eq("No consumers in the Takamaru topology: nothing to declare\n"))
    expect(Takamaru::RabbitMq::Connection).not_to(have_received(:start))
  end

  it 'fails on a missing env file' do
    expect(run('--environment', 'production', '--env-file', "#{dir}/.env.missing")).to(eq(1))

    expect(err.string).to(eq("takamaru-declare-queues: env file not found: #{dir}/.env.missing\n"))
    expect(Takamaru::RabbitMq::Connection).not_to(have_received(:start))
  end

  it 'fails on a missing section of the environment' do
    expect(run('--environment', 'staging')).to(eq(1))

    expect(err.string).to(eq("takamaru-declare-queues: #{dir}/rabbitmq.yml has no staging section\n"))
  end

  it 'fails on an unknown option' do
    expect(run('--unknown')).to(eq(1))

    expect(err.string).to(eq("takamaru-declare-queues: invalid option: --unknown\n"))
  end

  it 'runs without loading Rails nor ActiveSupport' do
    script = <<~RUBY
      require 'takamaru/declare_queues_command'
      puts [defined?(Rails), defined?(ActiveSupport)].inspect
      exit(Takamaru::DeclareQueuesCommand.new(['--topology', '#{dir}/takamaru.yml', '--environment', 'production']).run)
    RUBY
    write('takamaru.yml', "application_name: hurricane\n")

    stdout, stderr, status = Open3.capture3(RbConfig.ruby, '-Ilib', '-e', script)

    expect([status.success?, stderr]).to(eq([true, '']))
    expect(stdout).to(eq("[nil, nil]\nNo consumers in the Takamaru topology: nothing to declare\n"))
  end
end
