require 'spec_helper'

RSpec.describe(HurricaneClient) do
  describe '.insurance_company' do
    it 'returns an insurance company' do
      VCR.use_cassette('hurricane_client-insurance_company-Company+Name') do
        insurance_company = described_class.insurance_company('Company+Name')
        expect(insurance_company).to(be_a(Hash))
        expect(insurance_company['id']).to(eq('42'))
        expect(insurance_company['type']).to(eq('insuranceCompanies'))
        expect(insurance_company['attributes']&.keys).to(contain_exactly(*%w[createdAt updatedAt name]))
      end
    end
  end
end
