require 'rails/generators'
require 'rails/generators/active_record'

module Takamaru
  class MigrationGenerator < ::Rails::Generators::Base
    include ::Rails::Generators::Migration

    class << self
      def next_migration_number(dirname)
        ::ActiveRecord::Generators::Base.next_migration_number(dirname)
      end
    end

    protected

    def add_takamaru_migration(template, file_name = template)
      if self.class.migration_exists?(File.join(destination_root, 'db/migrate'), file_name)
        ::Kernel.warn("Migration already exists: #{file_name}")
      else
        migration_template("#{template}.rb.erb", "db/migrate/#{file_name}.rb", migration_version: migration_version)
      end
    end

    def migration_version
      "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
    end
  end
end
