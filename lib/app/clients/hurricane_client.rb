class HurricaneClient < ApplicationClient
  base_uri ENV.fetch('HURRICANE_BASE_URI')

  class << self
    def insurance_company(id)
      insurance_company_by(id)
    end

    def insurance_company_by_name(name)
      insurance_company_by(name)
    end

    def insurance_companies
      get('/api/v2/insurance_companies', options)
    end

    private

    def insurance_company_by(value)
      response = get(URI.encode("/api/v2/insurance_companies/#{value}"), options)
      return nil if response.code == 404

      # TODO: handle errors
      response.parsed_response.fetch('data').with_indifferent_access
    end
  end
end
