module Takamaru
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/takamaru.rake'
    end
  end
end
