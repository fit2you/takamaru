require 'rails_helper'

RSpec.describe(Takamaru::Shadowable) do
  let(:dummy_client) { DummyClient }
  let(:dummy_model) { DummyModel }

  it('has shadow attributes') do
    expect(dummy_model.shadow_attributes).to(eq(%i[attribute_1 attribute_2]))
  end

  it('has shadow client') do
    expect(dummy_model.instance_variable_get(:@shadow_client)).to(eq(DummyClient))
    expect(dummy_model.instance_variable_get(:@shadow_finder_method)).to(eq(:dummy_finder_method))
    expect(dummy_model.instance_variable_get(:@shadow_finder_by_method)).to(eq(:dummy_finder_by_method))
  end

  describe 'self.find_or_upsert_from_remote!' do
    describe 'with an existing record' do
      it('calls find once') do
        expect(dummy_model).to(receive(:find).once.and_return(dummy_model.new))
        expect(dummy_model).to_not(receive(:upsert_from_response!))

        dummy_model.find_or_upsert_from_remote!(42)
      end
    end

    describe 'with an unknown local record' do
      it('calls upsert_from_response! once') do
        expect(dummy_model).to(receive(:find).once)
        expect(dummy_model).to(receive(:upsert_from_response!).once)

        dummy_model.find_or_upsert_from_remote!(42)
      end
    end
  end

  describe 'self.find_or_upsert_from_remote_by_attribute!' do
    describe 'with an existing record' do
      it('calls find once') do
        expect(dummy_model).to(receive(:find_by).once.and_return(dummy_model.new))
        expect(dummy_model).to_not(receive(:upsert_from_response!))

        dummy_model.find_or_upsert_from_remote_by_attribute!(:value)
      end
    end

    describe 'with an unknown local record' do
      it('calls upsert_from_response! once') do
        expect(dummy_model).to(receive(:find_by).once)
        expect(dummy_model).to(receive(:upsert_from_response!).once)

        dummy_model.find_or_upsert_from_remote_by_attribute!(:value)
      end
    end
  end

  describe 'self.upsert_from_response!' do
    let(:response) { instance_double(HTTParty::Response, body: response_body) }
    let(:response_body) do
      { data: {
        id: 42,
        type: 'dummyModels',
        attributes: {},
      } }.to_json
    end

    it('returns a new dummy_model') do
      allow(response).to(receive(:parsed_response).and_return(JSON.parse(response_body)))
      expect(dummy_model.upsert_from_response!(response)).to(be_a(dummy_model))
    end
  end

  describe 'self.upsert_from_remote_by_attribute!' do
    it('calls upsert_from_remote_by! once') do
      expect(dummy_model).to(receive(:upsert_from_remote_by!).once)

      dummy_model.upsert_from_remote_by_attribute!(:value)
    end
  end
end
