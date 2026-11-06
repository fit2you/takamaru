require 'rails_helper'

RSpec.describe(Takamaru::Shadowable) do
  let(:document) do
    { 'data' => { 'id' => 42, 'type' => 'dummies', 'attributes' => { 'attribute_1' => 'one', 'attribute_2' => 'two' } } }
  end

  before do
    allow(DummyClient).to(receive(:dummy).with(42).and_return(document))
    allow(DummyClient).to(receive(:dummy_by).with('attribute_1', 'one').and_return(document))
  end

  it 'has shadow attributes' do
    expect(Dummy.shadow_attributes).to(eq(%i[attribute_1 attribute_2]))
  end

  it 'has shadow client and parser' do
    expect(Dummy.shadow_client).to(eq(DummyClient))
    expect(Dummy.shadow_parser).to(eq(Takamaru::JsonApiParser))
  end

  describe '.find_or_upsert_from_remote!' do
    it 'returns the local record when it exists' do
      dummy = Dummy.create!(id: 42)

      expect(Dummy.find_or_upsert_from_remote!(42)).to(eq(dummy))
      expect(DummyClient).not_to(have_received(:dummy))
    end

    it 'creates the record from the remote one' do
      dummy = Dummy.find_or_upsert_from_remote!(42)

      expect(dummy.reload).to(have_attributes(id: 42, attribute_1: 'one', attribute_2: 'two'))
    end
  end

  describe 'dynamic finders' do
    it 'finds or upserts by an attribute containing underscores' do
      dummy = Dummy.find_or_upsert_from_remote_by_attribute_1!('one')

      expect(dummy).to(have_attributes(id: 42, attribute_1: 'one'))
      expect(Dummy).to(respond_to(:find_or_upsert_from_remote_by_attribute_1!))
    end

    it 'upserts by an attribute' do
      Dummy.create!(id: 42, attribute_1: 'one')

      expect { Dummy.upsert_from_remote_by_attribute_1!('one') }.to(change { Dummy.find(42).attribute_2 }.to('two'))
    end

    it 'leaves other missing methods alone' do
      expect(Dummy).not_to(respond_to(:find_or_upsert_from_remote_by_name))
      expect { Dummy.find_or_upsert_from_remote_by_name('one') }.to(raise_error(NoMethodError))
    end
  end

  describe '.upsert_from_response!' do
    it 'uses the configured parser' do
      parser = ->(response) { { id: response[:key], attributes: { 'attribute_2' => 'parsed', 'ignored' => true } } }
      allow(Dummy).to(receive(:shadow_parser).and_return(parser))

      expect(Dummy.upsert_from_response!({ key: 7 })).to(have_attributes(id: 7, attribute_2: 'parsed'))
    end

    it 'updates the record created concurrently by another process' do
      existing = Dummy.create!(id: 42)
      # The first lookup happens before the other process commits: the insert hits the unique index
      lookups = 0
      allow(Dummy).to(receive(:find_or_initialize_by).and_wrap_original do |original, attributes|
        lookups += 1
        lookups == 1 ? Dummy.new(attributes) : original.call(attributes)
      end)

      Dummy.upsert_from_response!(document)

      expect(existing.reload.attribute_1).to(eq('one'))
    end
  end

  describe 'shadow attributes protection' do
    let(:dummy) { Dummy.upsert_from_response!(document) }

    it 'allows rewriting inside allow_shadow_attributes_rewriting' do
      dummy.allow_shadow_attributes_rewriting { |model| model.update!(attribute_1: 'new') }

      expect(dummy.reload.attribute_1).to(eq('new'))
    end

    it 'forbids rewriting outside allow_shadow_attributes_rewriting' do
      expect { dummy.attribute_1 = 'new' }.to(raise_error(ActiveRecord::ReadOnlyRecord))
    end

    it 'forbids rewriting again after the block raised' do
      expect { dummy.allow_shadow_attributes_rewriting { raise 'boom' } }.to(raise_error('boom'))

      expect { dummy.attribute_1 = 'new' }.to(raise_error(ActiveRecord::ReadOnlyRecord))
    end
  end
end
