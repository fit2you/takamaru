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

  describe 'self.find_or_upsert_from_remote_by!' do
    describe 'with an existing record' do
      it('calls find once') do
        expect(dummy_model).to(receive(:find_by).once.and_return(dummy_model.new))
        expect(dummy_model).to_not(receive(:upsert_from_response!))

        dummy_model.find_or_upsert_from_remote_by!(:attribute, :value)
      end
    end

    describe 'with an unknown local record' do
      it('calls upsert_from_response! once') do
        expect(dummy_model).to(receive(:find_by).once)
        expect(dummy_model).to(receive(:upsert_from_response!).once)

        dummy_model.find_or_upsert_from_remote_by!(:attribute, :value)
      end
    end
  end
end
