require 'rails_helper'

RSpec.describe(Takamaru::Topology) do
  subject(:topology) do
    described_class.new('application_name' => 'hurricane', 'consumers' => { 'users_consumer' => 'sasori.users' })
  end

  it 'names the queues after the application and the consumer' do
    expect(topology.queue_name_for('users_consumer')).to(eq('hurricane.users_consumer'))
  end

  it 'returns the exchange of a consumer' do
    expect(topology.exchange_name_for('users_consumer')).to(eq('sasori.users'))
  end

  it 'raises for a consumer not declared' do
    expect { topology.exchange_name_for('dealers_consumer') }
      .to(raise_error(Takamaru::ConfigurationError, 'Consumer dealers_consumer is not declared in the Takamaru topology'))
  end

  it 'allows no consumers' do
    expect(described_class.new('application_name' => 'hurricane').consumers).to(eq({}))
  end

  it 'requires the application name' do
    expect { described_class.new('consumers' => {}) }.to(raise_error(Takamaru::ConfigurationError, /application_name/))
  end

  it 'requires consumer names mapped to exchange names' do
    expect { described_class.new('application_name' => 'hurricane', 'consumers' => ['users_consumer']) }
      .to(raise_error(Takamaru::ConfigurationError, /consumers/))
  end

  describe '.load' do
    it 'reads a YAML file' do
      Tempfile.create(['takamaru', '.yml']) do |file|
        file.write("application_name: hurricane\nconsumers:\n  users_consumer: sasori.users\n")
        file.close

        expect(described_class.load(file.path).consumers).to(eq('users_consumer' => 'sasori.users'))
      end
    end

    it 'raises when the file does not exist' do
      expect { described_class.load('missing.yml') }
        .to(raise_error(Takamaru::ConfigurationError, 'Takamaru topology missing.yml not found'))
    end
  end
end
