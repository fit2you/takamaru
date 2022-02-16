module Takamaru
  module Shadowable
    extend ActiveSupport::Concern

    module ClassMethods
      def has_shadow_attributes(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}

        @client = options[:client] || HurricaneClient
        @method = options[:method] || name.underscore

        @shadow_attributes = args
      end
    end

    included do
      class << self
        def from_origin(param)
          response = @client.send(@method, param)

          data = response.parsed_response.fetch('data').with_indifferent_access

          origin_id = data[:id]
          origin_attributes = data[:attributes].deep_transform_keys do |k|
            k.to_s.underscore
          end.slice(*@shadow_attributes)

          record = find_or_initialize_by(id: origin_id)
          record.assign_attributes(origin_attributes)

          record
        end
      end
    end
  end
end
