require 'rails_helper'

RSpec.describe(Takamaru::Configuration) do
  subject(:config) { described_class.new }

  let(:topology) { Takamaru::Topology.new('application_name' => 'hurricane') }

  describe '#application_name' do
    it 'defaults to the application name of the topology' do
      config.topology = topology

      expect(config.application_name).to(eq('hurricane'))
    end

    it 'defaults to the module of the Rails application without topology' do
      config.topology = nil

      expect(config.application_name).to(eq('dummy_rails_app'))
    end

    it 'can be set to the application name of the topology' do
      config.topology = topology
      config.application_name = 'hurricane'

      expect(config.application_name).to(eq('hurricane'))
    end

    it 'raises when it differs from the topology' do
      config.topology = topology
      config.application_name = 'gordius'

      expect { config.application_name }
        .to(raise_error(Takamaru::ConfigurationError, 'application_name gordius differs from hurricane of the Takamaru topology'))
    end
  end

  describe '#topology' do
    it 'reads the topology file' do
      Tempfile.create(['takamaru', '.yml']) do |file|
        file.write("application_name: hurricane\n")
        file.close
        config.topology_path = file.path

        expect(config.topology.application_name).to(eq('hurricane'))
      end
    end

    it 'is nil when the topology file does not exist' do
      config.topology_path = 'missing.yml'

      expect(config.topology).to(be_nil)
    end
  end
end
