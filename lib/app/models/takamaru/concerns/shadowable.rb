module Takamaru
  module Shadowable
    extend ActiveSupport::Concern

    module ClassMethods
      def has_shadow_attributes(*attributes)
        @shadow_attributes = attributes
        # TODO: updates to shadow_attributes should be forbidden
      end

      def has_shadow_client(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}

        @client = args.first
        @finder_method = options[:finder_method] || name.underscore
        @finder_by_method = options[:finder_by_method] || "#{name.underscore}_by"
      end
    end

    included do
      class << self
        def find_or_upsert_from_remote!(id)
          find(id) || upsert_from_response(@client.send(@finder_method, id))
        end

        def find_or_upsert_from_remote_by!(attribute, value)
          find_by(attribute => value) || upsert_from_remote_by!(attribute, value)
        end

        def method_missing(method_name, *args)
          if method_name.to_s =~ /^find_or_upsert_from_remote_by_/
            key = method_name.to_s.split('_').last[0..-2]
            find_or_upsert_from_remote_by!(key, args.first)
          elsif method_name.to_s =~ /^upsert_from_remote_by_/
            key = method_name.to_s.split('_').last[0..-2]
            upsert_from_remote_by!(key, args.first)
          else
            super
          end
        end

        def upsert_from_response(response)
          data = response.parsed_response.fetch('data').with_indifferent_access

          origin_id = data[:id]
          origin_attributes = data[:attributes].deep_transform_keys { |k| k.to_s.underscore }.slice(*@shadow_attributes)

          record = find_or_initialize_by(id: origin_id)
          record.assign_attributes(origin_attributes)
          record.save!

          record
        end

        def respond_to_missing?(method_name, include_private = false)
          method_name.to_s.start_with?('find_or_upsert_from_remote_by_') ||
            method_name.to_s.start_with?('upsert_from_remote_by_') ||
            super
        end

        def upsert_from_remote!(id)
          upsert_from_response(@client.send(@finder_method, id))
        end

        def upsert_from_remote_by!(attribute, value)
          upsert_from_response(@client.send(@finder_by_method, attribute, value))
        end
      end
    end
  end
end
