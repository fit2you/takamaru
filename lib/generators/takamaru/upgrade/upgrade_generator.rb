require_relative '../migration_generator'

module Takamaru
  class UpgradeGenerator < MigrationGenerator
    source_root File.expand_path('templates', __dir__)

    desc 'Generates (but does not run) a migration to upgrade the commit log table created by takamaru < 1.0. ' \
      'See UPGRADING.md for more information.'
    def create_migration_files
      say('Generating migration files...')
      add_takamaru_migration('upgrade_takamaru_commit_logs_to_v1')
    end
  end
end
