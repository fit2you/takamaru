require 'spec_helper'

RSpec.describe(HurricaneClient) do
  describe '.insurance_company' do
    describe 'with an existing insurance company' do
      let(:id) { 42 }

      it 'returns the response' do
        VCR.use_cassette("hurricane_client-insurance_company-#{id}") do
          response = HurricaneClient.insurance_company(id)
          expect(response).to(be_a(HTTParty::Response))
        end
      end
    end

    describe 'with an unknown insurance company' do
      let(:id) { 21 }

      it 'raises a Takamaru::RecordNotFound' do
        VCR.use_cassette("hurricane_client-insurance_company-#{id}") do
          expect do
            HurricaneClient.insurance_company(id)
          end.to(raise_error(Takamaru::RecordNotFound))
        end
      end
    end
  end

  describe '.insurance_company_by' do
    describe 'with an existing insurance company' do
      let(:attribute) { :name }
      let(:value) { 'Company Name' }

      it 'returns the response' do
        VCR.use_cassette("hurricane_client-insurance_company_by-#{attribute}-#{value.underscore}") do
          response = HurricaneClient.insurance_company_by(attribute, value)
          expect(response).to(be_a(HTTParty::Response))
        end
      end
    end

    describe 'with an unknown insurance company' do
      let(:attribute) { :name }
      let(:value) { 'Unknown Company' }

      it 'raises a Takamaru::RecordNotFound' do
        VCR.use_cassette("hurricane_client-insurance_company_by-#{attribute}-#{value.underscore}") do
          expect do
            HurricaneClient.insurance_company_by(attribute, value)
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
