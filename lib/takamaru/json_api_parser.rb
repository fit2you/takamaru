module Takamaru
  # Default parser of Shadowable: reads a parsed JSON:API document such as
  #   { 'data' => { 'id' => 42, 'attributes' => { 'vatNumber' => '...' } } }
  # Any object answering to #fetch('data') works, e.g. a Hash or an HTTParty::Response.
  module JsonApiParser
    class << self
      def call(document)
        data = document.fetch('data')
        attributes = (data['attributes'] || {}).deep_transform_keys { |key| key.to_s.underscore }

        { id: data.fetch('id'), attributes: attributes }
      end
    end
  end
end
