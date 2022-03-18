require 'rubycritic/rake_task'

namespace :code do
  desc 'Checks the quality of code and generate reports'
  task :quality do
    puts
    puts '== Patch-level verification for bundler '.ljust(80, '=')
    puts
    system 'bundle-audit update && bundle-audit'
    puts
    puts '== Quality report generation '.ljust(80, '=')
    puts
    Rake.application.invoke_task('code:rubycritic')
    puts
  end

  RubyCritic::RakeTask.new do |task|
    task.name = 'rubycritic'

    task.paths = FileList.new(
      'lib/**/*.rb',
    )

    task.options = ''
  end
end
