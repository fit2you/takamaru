require 'rails_helper'

RSpec.describe(Takamaru::Shadowable) do
  let(:document) do
    { 'data' => { 'id' => 42, 'type' => 'dummies', 'attributes' => { 'attribute_1' => 'one', 'attribute_2' => 'two' } } }
  end

  let(:client) { Dummy.shadow_client }

  before do
    allow(client).to(receive(:find).with(42).and_return(document))
    allow(client).to(receive(:find_by).with('attribute_1', 'one').and_return(document))
  end

  it 'has shadow attributes' do
    expect(Dummy.shadow_attributes).to(eq(%i[attribute_1 attribute_2]))
  end

  it 'has a shadow client' do
    expect(Dummy.shadow_client).to(be_a(DummyClient))
  end

  describe '.has_shadow_client' do
    it 'rejects a client that is not a Takamaru::ShadowClient' do
      model = Class.new(ActiveRecord::Base) { include Takamaru::Shadowable }

      expect { model.has_shadow_client(Object.new) }.to(raise_error(ArgumentError, /Takamaru::ShadowClient/))
    end
  end

  describe '.find_or_upsert_from_remote!' do
    it 'returns the local record when it exists' do
      dummy = Dummy.create!(id: 42)

      expect(Dummy.find_or_upsert_from_remote!(42)).to(eq(dummy))
      expect(client).not_to(have_received(:find))
    end

    it 'creates the record from the remote one' do
      dummy = Dummy.find_or_upsert_from_remote!(42)

      expect(dummy.reload).to(have_attributes(id: 42, attribute_1: 'one', attribute_2: 'two'))
    end

    it 'lets the client report a missing remote record' do
      allow(client).to(receive(:find).with(7).and_raise(Takamaru::RemoteRecordNotFound))

      expect { Dummy.find_or_upsert_from_remote!(7) }.to(raise_error(Takamaru::RemoteRecordNotFound))
      expect(Dummy.exists?(7)).to(be(false))
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
    it 'parses the response with the client' do
      allow(client).to(receive(:parse).and_wrap_original do |_original, response|
        { id: response[:key], attributes: { 'attribute_2' => 'parsed', 'ignored' => true } }
      end)

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

  describe 'versioning with remote_updated_at' do
    let(:newer) { '2026-11-06T10:00:00.000002Z' }
    let(:older) { '2026-11-06T10:00:00.000001Z' }

    def response(attribute_1, updated_at)
      attributes = { 'attribute_1' => attribute_1, 'updatedAt' => updated_at }.compact
      { 'data' => { 'id' => 42, 'type' => 'dummies', 'attributes' => attributes } }
    end

    it 'saves the updated_at of the remote record, with microseconds' do
      Dummy.upsert_from_response!(response('new', newer))

      expect(Dummy.find(42).remote_updated_at).to(eq(Time.iso8601(newer)))
    end

    it 'skips a response older than the applied one' do
      Dummy.upsert_from_response!(response('new', newer))

      record = Dummy.upsert_from_response!(response('old', older))

      expect(record).to(have_attributes(attribute_1: 'new', remote_updated_at: Time.iso8601(newer)))
      expect(Dummy.find(42)).to(have_attributes(attribute_1: 'new', remote_updated_at: Time.iso8601(newer)))
    end

    it 'applies a newer response' do
      Dummy.upsert_from_response!(response('old', older))
      Dummy.upsert_from_response!(response('new', newer))

      expect(Dummy.find(42)).to(have_attributes(attribute_1: 'new', remote_updated_at: Time.iso8601(newer)))
    end

    it 'applies a response with the same version again' do
      Dummy.upsert_from_response!(response('one', newer))
      Dummy.upsert_from_response!(response('two', newer))

      expect(Dummy.find(42).attribute_1).to(eq('two'))
    end

    it 'applies a response without updated_at, keeping the saved version' do
      Dummy.upsert_from_response!(response('old', newer))
      Dummy.upsert_from_response!(response('new', nil))

      expect(Dummy.find(42)).to(have_attributes(attribute_1: 'new', remote_updated_at: Time.iso8601(newer)))
    end

    it 'locks the row before comparing the versions' do
      Dummy.upsert_from_response!(response('old', older))
      queries = []
      callback = ->(*, payload) { queries << payload[:sql] }

      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        Dummy.upsert_from_response!(response('new', newer))
      end

      expect(queries).to(include(/FOR UPDATE/))
    end

    it 'ignores updated_at when the table has no remote_updated_at' do
      allow(Dummy).to(receive(:shadow_versioned?).and_return(false))

      Dummy.upsert_from_response!(response('new', newer))

      expect(Dummy.find(42)).to(have_attributes(attribute_1: 'new', remote_updated_at: nil))
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
