require_relative '../migration_generator'

module Takamaru
  class ShadowVersionGenerator < MigrationGenerator
    source_root File.expand_path('templates', __dir__)

    argument :model, type: :string, desc: 'The shadow model, e.g. User'

    desc 'Generates (but does not run) a migration adding remote_updated_at to the table of a shadow model, so that ' \
      'Takamaru::Shadowable skips responses older than the applied one. See Shadow models section in README.md.'
    def create_migration_files
      say('Generating migration files...')
      add_takamaru_migration('add_remote_updated_at', "add_remote_updated_at_to_#{table_name}")
    end

    private

    def table_name
      model.underscore.tr('/', '_').pluralize
    end
  end
end
