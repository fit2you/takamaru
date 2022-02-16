class HurricaneClient < ApplicationClient
  base_uri ENV.fetch('HURRICANE_BASE_URI')

  class << self
    def insurance_company(param)
      get("/api/v2/insurance_companies/#{CGI.escape(param.to_s)}", options)
      # TODO: handle errors
    end

    def insurance_companies
      get('/api/v2/insurance_companies', options)
    end

    def user(id)
      user_by(id)
    end

    private

    def user_by(value)
      response = get("/api/v2/users/#{CGI.escape(value.to_s)}", options)
      return nil if response.code == 404

      # TODO: handle errors
      response.parsed_response.fetch('data').with_indifferent_access
    end
  end
end
