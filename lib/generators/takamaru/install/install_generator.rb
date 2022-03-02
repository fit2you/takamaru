require_relative '../migration_generator'

module Takamaru
  class InstallGenerator < MigrationGenerator
    source_root File.expand_path('templates', __dir__)

    desc 'Generates (but does not run) a migration to add a commit log table.' \
      'See Generators section in README.md for more information.'
    def create_migration_files
      say('Generating migration files...')
      add_takamaru_migration('create_takamaru_commit_logs')
      add_takamaru_migration('create_takamaru_unhandled_message_logs')
    end
  end
end
