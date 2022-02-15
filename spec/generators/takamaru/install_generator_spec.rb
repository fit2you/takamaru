require 'spec_helper'

require 'generator_spec/test_case'
require 'generators/takamaru/install/install_generator'

RSpec.describe(Takamaru::InstallGenerator) do
  include GeneratorSpec::TestCase
  destination File.expand_path('tmp')

  before do
    prepare_destination
    run_generator
  end

  after do
    prepare_destination
  end

  context 'when a migration does not exist' do
    it "generates a migration for creating the 'takamaru_commit_logs' table" do
      expected_parent_class = lambda {
        old_school = 'ActiveRecord::Migration'
        ar_version = ActiveRecord::VERSION
        format('%s[%d.%d]', old_school, ar_version::MAJOR, ar_version::MINOR)
      }.call

      expect(destination_root).to(
        have_structure do
          directory('db') do
            directory('migrate') do
              migration('create_takamaru_commit_logs') do
                contains('class CreateTakamaruCommitLogs < ' + expected_parent_class)
                contains('def change')
                contains('create_table :takamaru_commit_logs do |t|')
                contains('  t.string :exchange_name, null: false')
                contains('  t.json :payload, null: false')
                contains('  t.timestamps null: false')
              end
            end
          end
        end
      )
    end
  end

  context 'when a migration already exists' do
    it 'does not generate a new migration' do
      expect { run_generator }.to(output(/^Migration already exists: .*$/).to_stderr)
    end
  end
end
