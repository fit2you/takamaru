namespace :code_quality do
  desc 'Checks the quality of code and generate reports'
  task :check do
    puts
    puts '== Patch-level verification for bundler '.ljust(80, '=')
    puts
    system 'bundle-audit update && bundle-audit'
    puts
    puts '== Quality report generation '.ljust(80, '=')
    puts
    system 'rubycritic'
    puts
  end
end
