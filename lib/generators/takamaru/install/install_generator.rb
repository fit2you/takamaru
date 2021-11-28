require_relative '../migration_generator'

module Takamaru
  class InstallGenerator < MigrationGenerator
    source_root File.expand_path('templates', __dir__)

    desc 'Generates (but does not run) a migration to add a commit log table.' \
      'See Generators section in README.md for more information.'

    def create_migration_file
      add_takamaru_migration('create_takamaru_commit_logs')
    end
  end
end
