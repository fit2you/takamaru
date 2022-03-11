module Takamaru
  module Shadowable
    extend ActiveSupport::Concern

    module ClassMethods
      attr_reader :shadow_client

      def has_shadow_attributes(*attributes)
        @shadow_attributes = attributes
        instance_eval do
          @shadow_attributes.each { |attribute| define_instance_writer(attribute) }
        end
      end

      def has_shadow_client(client)
        @shadow_client = client
        name_underscored = name.underscore
        @shadow_finder_method = name_underscored
        @shadow_finder_by_method = "#{name_underscored}_by"
      end

      def shadow_attributes
        @shadow_attributes ||= []
      end

      private

      def define_instance_writer(attribute)
        define_method("#{attribute}=") do |value|
          if persisted? && !shadow_attributes_rewritable?
            raise ActiveRecord::ReadOnlyRecord,
              "#{self.class.name}'s shadow attribute '#{attribute}' should not be changed manually!"
          end

          super(value)
        end
      end
    end

    included do
      class << self
        def find_or_upsert_from_remote!(id)
          find(id)
        rescue ActiveRecord::RecordNotFound
          upsert_from_remote!(id)
        end

        def find_or_upsert_from_remote_by!(attribute, value)
          find_by(attribute => value) || upsert_from_remote_by!(attribute, value)
        end

        def initialize_record(id, attributes)
          record = find_or_initialize_by(id: id)
          record.allow_shadow_attributes_rewriting do |instance|
            instance.assign_attributes(attributes)
            instance.save!
          end

          record
        end

        def method_missing(method_name, *args)
          dynamic_upsert_methods_prefixes = %w[find_or_upsert_from_remote_by_ upsert_from_remote_by_]
          return foo(method_name, *args) if method_name.to_s.gsub(/[^_]+$/, '').in?(dynamic_upsert_methods_prefixes)

          super
        end

        def foo(method_name, *args)
          _, method, attribute = method_name.to_s.match(/^(.*)_([^_]+)!$/).to_a
          value = args.first

          send("#{method}!", attribute, value)
        end

        def upsert_from_response!(response)
          data = response.parsed_response.fetch('data').with_indifferent_access

          origin_id = data[:id]
          origin_attributes = data[:attributes].deep_transform_keys do |key|
            key.to_s.underscore
          end.slice(*@shadow_attributes)

          initialize_record(origin_id, origin_attributes)
        end

        def respond_to_missing?(method_name, include_private = false)
          string_method_name = method_name.to_s

          string_method_name.start_with?('find_or_upsert_from_remote_by_', 'upsert_from_remote_by_') || super
        end

        def upsert_from_remote!(id)
          upsert_from_response!(@shadow_client.send(@shadow_finder_method, id))
        end

        def upsert_from_remote_by!(attribute, value)
          upsert_from_response!(@shadow_client.send(@shadow_finder_by_method, attribute, value))
        end
      end

      def allow_shadow_attributes_rewriting(&block)
        @shadow_attributes_rewritable = true
        yield self
        @shadow_attributes_rewritable = false
      end

      def shadow_attributes_rewritable?
        @shadow_attributes_rewritable
      end
    end
  end
end
