RSpec.configure do |config|
  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation, except: %w[ar_internal_metadata])
  end

  # Examples tagged :committed see their data from other connections, e.g. to test row locks
  config.around(:each) do |example|
    DatabaseCleaner.strategy = example.metadata[:committed] ? :deletion : :transaction
    DatabaseCleaner.cleaning do
      example.run
    end
  end
end
