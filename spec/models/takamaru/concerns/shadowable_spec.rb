require 'rails_helper'

RSpec.describe(Takamaru::Shadowable) do
  let(:dummy_client_class) { DummyClient }
  let(:dummy_class) { Dummy }

  it('has shadow attributes') do
    expect(dummy_class.shadow_attributes).to(eq(%i[attribute_1 attribute_2]))
    expect(dummy_class.new).to(respond_to(:attribute_1=))
    expect(dummy_class.new).to(respond_to(:attribute_2=))
  end

  it('has shadow client') do
    expect(dummy_class.instance_variable_get(:@shadow_client)).to(eq(dummy_client_class))
    expect(dummy_class.instance_variable_get(:@shadow_finder_method)).to(eq('dummy'))
    expect(dummy_class.instance_variable_get(:@shadow_finder_by_method)).to(eq('dummy_by'))
  end

  describe 'self.find_or_upsert_from_remote!' do
    describe 'with an existing record' do
      it('calls find once') do
        expect(dummy_class).to(receive(:find).once.and_return(dummy_class.new))
        expect(dummy_class).to_not(receive(:upsert_from_response!))

        dummy_class.find_or_upsert_from_remote!(42)
      end
    end

    describe 'with an unknown local record' do
      it('calls upsert_from_response! once') do
        expect(dummy_class).to(receive(:find).once.and_raise(ActiveRecord::RecordNotFound))
        expect(dummy_class).to(receive(:upsert_from_response!).once)

        dummy_class.find_or_upsert_from_remote!(42)
      end
    end
  end

  describe 'self.find_or_upsert_from_remote_by_attribute!' do
    describe 'with an existing record' do
      it('calls find once') do
        expect(dummy_class).to(receive(:find_by).once.and_return(dummy_class.new))
        expect(dummy_class).to_not(receive(:upsert_from_response!))

        dummy_class.find_or_upsert_from_remote_by_attribute!(:value)
      end
    end

    describe 'with an unknown local record' do
      it('calls upsert_from_response! once') do
        expect(dummy_class).to(receive(:find_by).once)
        expect(dummy_class).to(receive(:upsert_from_response!).once)

        dummy_class.find_or_upsert_from_remote_by_attribute!(:value)
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

    it('returns a new dummy_class') do
      allow(response).to(receive(:parsed_response).and_return(JSON.parse(response_body)))
      expect(dummy_class.upsert_from_response!(response)).to(be_a(dummy_class))
    end
  end

  describe 'self.upsert_from_remote_by_attribute!' do
    it('calls upsert_from_remote_by! once') do
      expect(dummy_class).to(receive(:upsert_from_remote_by!).once)

      dummy_class.upsert_from_remote_by_attribute!(:value)
    end
  end

  describe 'rewrite shadow attributes' do
    let(:attribute_1) { 'attribute_1' }
    let(:attribute_2) { 'attribute_2' }
    let(:dummy) { dummy_class.upsert_from_response!(response) }
    let(:response) { instance_double(HTTParty::Response, body: response_body) }
    let(:response_body) do
      { data: {
        id: 42,
        type: 'dummyShadowableModels',
        attributes: {
          attribute_1: attribute_1,
          attribute_2: attribute_2,
        },
      } }.to_json
    end

    before do
      allow(response).to(receive(:parsed_response).and_return(JSON.parse(response_body)))
    end

    describe 'with a new record' do
      it 'persists the shadow attributes' do
        expect(dummy.reload.attribute_1).to(eq(attribute_1))
        expect(dummy.reload.attribute_2).to(eq(attribute_2))
      end
    end

    describe 'with an existing record' do
      before do
        dummy_class.upsert_from_response!(response)
      end

      describe 'with allowed shadow attributes rewriting' do
        it 'persists the shadow attributes' do
          expect do
            dummy.allow_shadow_attributes_rewriting do |model|
              model.attribute_1 = 'new_attribute_1'
              model.attribute_2 = 'new_attribute_2'
              model.save!
            end
          end.to(change { dummy.reload.attribute_1 }.from(attribute_1).to('new_attribute_1')
            .and(change { dummy.reload.attribute_2 }.from(attribute_2).to('new_attribute_2')))
        end
      end

      describe 'with disallowed shadow attributes rewriting' do
        it 'does not persist the shadow attributes' do
          expect do
            dummy.attribute_1 = 'new_attribute_1'
          end.to(raise_error(ActiveRecord::ReadOnlyRecord)
            .and(not_change { dummy.reload.attribute_1 })
            .and(not_change { dummy.reload.attribute_2 }))
        end
      end
    end
  end
end
