require 'rails_helper'

require 'generator_spec/test_case'
require 'generators/takamaru/shadow_version/shadow_version_generator'

RSpec.describe(Takamaru::ShadowVersionGenerator) do
  include GeneratorSpec::TestCase

  destination File.expand_path('tmp')
  arguments %w[Admin::User]

  before do
    prepare_destination
    run_generator
  end

  after do
    prepare_destination
  end

  it 'generates the migration adding remote_updated_at to the table of the model' do
    migration_class = "ActiveRecord::Migration[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"

    expect(destination_root).to(
      have_structure do
        directory('db') do
          directory('migrate') do
            migration('add_remote_updated_at_to_admin_users') do
              contains("class AddRemoteUpdatedAtToAdminUsers < #{migration_class}")
              contains('add_column(:admin_users, :remote_updated_at, :datetime, precision: 6)')
            end
          end
        end
      end,
    )
  end

  it 'does not generate the migration twice' do
    expect { run_generator }.to(output(/^Migration already exists: add_remote_updated_at_to_admin_users$/).to_stderr)
  end
end
