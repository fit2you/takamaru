require 'rails/generators'
require 'rails/generators/active_record'

module Takamaru
  class MigrationGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration

    def self.next_migration_number(dirname)
      ::ActiveRecord::Generators::Base.next_migration_number(dirname)
    end

    protected

    def add_takamaru_migration(template, extra_options = {})
      migration_dir = File.expand_path(Rails.env.test? ? 'tmp/db/migrate' : 'db/migrate')
      if self.class.migration_exists?(migration_dir, template)
        ::Kernel.warn("Migration already exists: #{template}")
      else
        migration_template(
          "#{template}.rb.erb",
          "db/migrate/#{template}.rb",
          { migration_version: migration_version }.merge(extra_options)
        )
      end
    end

    def migration_version
      return '' if ::ActiveRecord::VERSION::MAJOR < 5
      format(
        '[%d.%d]',
        ActiveRecord::VERSION::MAJOR,
        ActiveRecord::VERSION::MINOR
      )
    end
  end
end
