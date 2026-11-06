module Takamaru
  # Local read-only copy ("shadow") of records owned by another service.
  #
  #   class User < ApplicationRecord
  #     include Takamaru::Shadowable
  #
  #     has_shadow_attributes :email, :name
  #     has_shadow_client UsersClient                     # UsersClient.user(id), UsersClient.user_by(attribute, value)
  #     has_shadow_client UsersClient, parser: MyParser   # MyParser.call(response) returns { id:, attributes: }
  #   end
  #
  #   User.find_or_upsert_from_remote!(42)
  #   User.find_or_upsert_from_remote_by_email!('jane@example.com')
  module Shadowable
    extend ActiveSupport::Concern

    DYNAMIC_FINDER = /\A(find_or_upsert_from_remote_by|upsert_from_remote_by)_(.+)!\z/

    included do
      class_attribute :shadow_attributes, instance_accessor: false, default: []
      class_attribute :shadow_client, instance_accessor: false
      class_attribute :shadow_parser, instance_accessor: false, default: JsonApiParser
    end

    class_methods do
      def has_shadow_attributes(*attributes)
        self.shadow_attributes = attributes
        attributes.each { |attribute| define_shadow_attribute_writer(attribute) }
      end

      def has_shadow_client(client, parser: JsonApiParser)
        self.shadow_client = client
        self.shadow_parser = parser
      end

      def find_or_upsert_from_remote!(id)
        find_by(id: id) || upsert_from_remote!(id)
      end

      def find_or_upsert_from_remote_by!(attribute, value)
        find_by(attribute => value) || upsert_from_remote_by!(attribute, value)
      end

      def upsert_from_remote!(id)
        upsert_from_response!(shadow_client.public_send(model_name.singular, id))
      end

      def upsert_from_remote_by!(attribute, value)
        upsert_from_response!(shadow_client.public_send("#{model_name.singular}_by", attribute, value))
      end

      def upsert_from_response!(response)
        parsed = shadow_parser.call(response)
        attributes = parsed.fetch(:attributes).with_indifferent_access.slice(*shadow_attributes)

        initialize_record(parsed.fetch(:id), attributes)
      end

      def initialize_record(id, attributes)
        save_shadow_record(id, attributes)
      rescue ActiveRecord::RecordNotUnique
        # Another process inserted the same record in the meantime: now it is found and updated.
        save_shadow_record(id, attributes)
      end

      def method_missing(method_name, *args)
        match = DYNAMIC_FINDER.match(method_name.to_s)
        return super unless match

        finder, attribute = match.captures
        public_send("#{finder}!", attribute, *args)
      end

      def respond_to_missing?(method_name, include_private = false)
        DYNAMIC_FINDER.match?(method_name.to_s) || super
      end

      private

      def save_shadow_record(id, attributes)
        record = find_or_initialize_by(id: id)
        record.allow_shadow_attributes_rewriting { record.update!(attributes) }
        record
      end

      def define_shadow_attribute_writer(attribute)
        define_method("#{attribute}=") do |value|
          if persisted? && !shadow_attributes_rewritable?
            raise ActiveRecord::ReadOnlyRecord,
              "#{self.class.name}'s shadow attribute '#{attribute}' should not be changed manually!"
          end

          super(value)
        end
      end
    end

    def allow_shadow_attributes_rewriting
      @shadow_attributes_rewritable = true
      yield(self)
    ensure
      @shadow_attributes_rewritable = false
    end

    def shadow_attributes_rewritable?
      @shadow_attributes_rewritable == true
    end
  end
end
