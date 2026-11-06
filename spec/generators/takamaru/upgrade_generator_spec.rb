require 'rails_helper'

require 'generator_spec/test_case'
require 'generators/takamaru/upgrade/upgrade_generator'

RSpec.describe(Takamaru::UpgradeGenerator) do
  include GeneratorSpec::TestCase

  destination File.expand_path('tmp')

  before do
    prepare_destination
    run_generator
  end

  after do
    prepare_destination
  end

  it 'generates the migration upgrading the takamaru_commit_logs table' do
    expect(destination_root).to(
      have_structure do
        directory('db') do
          directory('migrate') do
            migration('upgrade_takamaru_commit_logs_to_v1') do
              contains('class UpgradeTakamaruCommitLogsToV1 < ActiveRecord::Migration[')
              contains('add_column(:takamaru_commit_logs, :message_id, :uuid)')
              contains('change_column_null(:takamaru_commit_logs, :message_id, false)')
            end
          end
        end
      end,
    )
  end
end
