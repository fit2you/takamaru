require 'rails_helper'

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

  context 'when the migration does not exist' do
    it 'generates the migration creating the takamaru_commit_logs table' do
      migration_class = "ActiveRecord::Migration[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"

      expect(destination_root).to(
        have_structure do
          directory('db') do
            directory('migrate') do
              migration('create_takamaru_commit_logs') do
                contains("class CreateTakamaruCommitLogs < #{migration_class}")
                contains('create_table(:takamaru_commit_logs) do |t|')
                contains('t.uuid(:message_id, null: false, index: { unique: true })')
                contains('t.datetime(:published_at, index: true)')
                contains("where: 'published_at IS NULL'")
              end
            end
          end
        end,
      )
    end
  end

  context 'when the migration already exists' do
    it 'does not generate a new migration' do
      expect { run_generator }.to(output(/^Migration already exists: .*$/).to_stderr)
    end
  end
end
