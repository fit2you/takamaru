class HurricaneClient < ApplicationClient
  base_uri ENV.fetch('HURRICANE_BASE_URI')

  class << self
    def insurance_company(param)
      do_request(:get, "/api/v2/insurance_companies/#{CGI.escape(param.to_s)}", options)
    end

    def user(id)
      do_request(:get, "/api/v2/insurance_companies/#{id}", options)
    end
  end
end
