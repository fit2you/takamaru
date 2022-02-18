require 'rails_helper'

RSpec.describe(Takamaru::Shadowable) do
  let(:dummy_client_class) { DummyClient }
  let(:dummy_shadowable_class) { DummyShadowable }

  it('has shadow attributes') do
    expect(dummy_shadowable_class.shadow_attributes).to(eq(%i[attribute_1 attribute_2]))
  end

  it('has shadow client') do
    expect(dummy_shadowable_class.instance_variable_get(:@shadow_client)).to(eq(dummy_client_class))
    expect(dummy_shadowable_class.instance_variable_get(:@shadow_finder_method)).to(eq('dummy_shadowable'))
    expect(dummy_shadowable_class.instance_variable_get(:@shadow_finder_by_method)).to(eq('dummy_shadowable_by'))
  end

  describe 'self.find_or_upsert_from_remote!' do
    describe 'with an existing record' do
      it('calls find once') do
        expect(dummy_shadowable_class).to(receive(:find).once.and_return(dummy_shadowable_class.new))
        expect(dummy_shadowable_class).to_not(receive(:upsert_from_response!))

        dummy_shadowable_class.find_or_upsert_from_remote!(42)
      end
    end

    describe 'with an unknown local record' do
      it('calls upsert_from_response! once') do
        expect(dummy_shadowable_class).to(receive(:find).once.and_raise(ActiveRecord::RecordNotFound))
        expect(dummy_shadowable_class).to(receive(:upsert_from_response!).once)

        dummy_shadowable_class.find_or_upsert_from_remote!(42)
      end
    end
  end

  describe 'self.find_or_upsert_from_remote_by_attribute!' do
    describe 'with an existing record' do
      it('calls find once') do
        expect(dummy_shadowable_class).to(receive(:find_by).once.and_return(dummy_shadowable_class.new))
        expect(dummy_shadowable_class).to_not(receive(:upsert_from_response!))

        dummy_shadowable_class.find_or_upsert_from_remote_by_attribute!(:value)
      end
    end

    describe 'with an unknown local record' do
      it('calls upsert_from_response! once') do
        expect(dummy_shadowable_class).to(receive(:find_by).once)
        expect(dummy_shadowable_class).to(receive(:upsert_from_response!).once)

        dummy_shadowable_class.find_or_upsert_from_remote_by_attribute!(:value)
      end
    end
  end

  describe 'self.upsert_from_response!' do
    let(:response) { instance_double(HTTParty::Response, body: response_body) }
    let(:response_body) do
      { data: {
        id: 42,
        type: 'dummyShadowableModels',
        attributes: {},
      } }.to_json
    end

    it('returns a new dummy_shadowable_class') do
      allow(response).to(receive(:parsed_response).and_return(JSON.parse(response_body)))
      expect(dummy_shadowable_class.upsert_from_response!(response)).to(be_a(dummy_shadowable_class))
    end
  end

  describe 'self.upsert_from_remote_by_attribute!' do
    it('calls upsert_from_remote_by! once') do
      expect(dummy_shadowable_class).to(receive(:upsert_from_remote_by!).once)

      dummy_shadowable_class.upsert_from_remote_by_attribute!(:value)
    end
  end
end
