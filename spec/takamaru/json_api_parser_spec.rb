require 'rails_helper'

RSpec.describe(Takamaru::JsonApiParser) do
  it 'returns id and underscored attributes' do
    document = { 'data' => { 'id' => 42, 'attributes' => { 'vatNumber' => '123', 'address' => { 'zipCode' => '00100' } } } }

    expect(described_class.call(document)).to(eq(
      id: 42,
      attributes: { 'vat_number' => '123', 'address' => { 'zip_code' => '00100' } },
    ))
  end

  it 'returns empty attributes when the document has none' do
    expect(described_class.call({ 'data' => { 'id' => 42 } })).to(eq(id: 42, attributes: {}))
  end
end
