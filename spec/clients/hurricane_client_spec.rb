require 'spec_helper'

RSpec.describe(HurricaneClient) do
  describe '.insurance_company' do
    describe 'with an existing insurance company' do
      let(:param) { 'Company Name' }

      it 'returns the response' do
        VCR.use_cassette("hurricane_client-insurance_company-#{CGI.escape(param)}") do
          response = HurricaneClient.insurance_company(param)
          expect(response).to(be_a(HTTParty::Response))
        end
      end
    end

    describe 'with an unknown insurance company' do
      let(:param) { 'Unknown Company' }

      it 'raises a Takamaru::RecordNotFound' do
        VCR.use_cassette("hurricane_client-insurance_company-#{CGI.escape(param)}") do
          expect do
            HurricaneClient.insurance_company(param)
          end.to(raise_error(Takamaru::RecordNotFound))
        end
      end
    end
  end

  describe '.user' do
    describe 'with an existing user' do
      let(:id) { 42 }

      it 'returns the response' do
        VCR.use_cassette("hurricane_client-user-#{id}") do
          response = HurricaneClient.user(id)
          expect(response).to(be_a(HTTParty::Response))
        end
      end
    end

    describe 'with an unknown user' do
      let(:id) { 21 }

      it 'raises a Takamaru::RecordNotFound' do
        VCR.use_cassette("hurricane_client-user-#{id}") do
          expect do
            HurricaneClient.user(id)
          end.to(raise_error(Takamaru::RecordNotFound))
        end
      end
    end
  end
end
