namespace :code do
  desc 'Checks the quality of code and generate reports'
  task :quality do
    puts
    puts '== Patch-level verification for bundler '.ljust(80, '=')
    puts
    abort unless system('bundle-audit update && bundle-audit')

    puts
    puts '== Checking for security vulnerabilities '.ljust(80, '=')
    abort unless system('brakeman lib -q --color')

    puts '== Quality report generation '.ljust(80, '=')
    puts
    paths = FileList.new(
      'lib/**/*.rb'
    ).join(' ')
    abort unless system("rubycritic #{paths}")
  end
end
