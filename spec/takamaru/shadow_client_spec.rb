require 'rails_helper'

RSpec.describe(Takamaru::ShadowClient) do
  subject(:client) { Class.new(described_class).new }

  it 'requires subclasses to implement find and find_by' do
    expect { client.find(42) }.to(raise_error(NotImplementedError, /#find\(id\)/))
    expect { client.find_by('email', 'jane@example.com') }.to(raise_error(NotImplementedError, /#find_by/))
  end

  it 'parses JSON:API documents by default' do
    document = { 'data' => { 'id' => 42, 'attributes' => { 'vatNumber' => 'IT1' } } }

    expect(client.parse(document)).to(eq(id: 42, attributes: { 'vat_number' => 'IT1' }))
  end
end
