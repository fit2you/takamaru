class ApplicationClient
  include HTTParty

  default_timeout 120
  debug_output($stdout) if Rails.env.development?

  class << self
    private

    def json_header
      { 'Content-Type' => 'application/json' }
    end

    def options
      { headers: json_header }
    end
  end
end
