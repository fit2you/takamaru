class HurricaneClient < ApplicationClient
  base_uri ENV.fetch('HURRICANE_BASE_URI')

  class << self
    def insurance_company(id)
      do_request(:get, "/api/v2/insurance_companies/#{id}", options)
    end

    def insurance_company_by(attribute, value)
      do_request(:get, "/api/v2/insurance_companies/by/#{attribute}/#{CGI.escape(value)}", options)
    end

    def user(id)
      do_request(:get, "/api/v2/users/#{id}", options)
    end
  end
end
