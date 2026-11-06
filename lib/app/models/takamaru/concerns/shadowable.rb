module Takamaru
  # Local read-only copy ("shadow") of records owned by another service.
  #
  #   class User < ApplicationRecord
  #     include Takamaru::Shadowable
  #
  #     has_shadow_attributes :email, :name
  #     has_shadow_client UsersShadowClient.new # a Takamaru::ShadowClient
  #   end
  #
  #   User.find_or_upsert_from_remote!(42)
  #   User.find_or_upsert_from_remote_by_email!('jane@example.com')
  #
  # Versioning: when the table has a `remote_updated_at` column (rails generate takamaru:shadow_version User), it keeps
  # the `updated_at` of the remote record last applied, and a response older than it is skipped. Two jobs of the same
  # record can run concurrently: without it, the one reading first but saving last would restore the older state.
  module Shadowable
    extend ActiveSupport::Concern

    DYNAMIC_FINDER = /\A(find_or_upsert_from_remote_by|upsert_from_remote_by)_(.+)!\z/
    VERSION_COLUMN = 'remote_updated_at'

    included do
      class_attribute :shadow_attributes, instance_accessor: false, default: []
      class_attribute :shadow_client, instance_accessor: false
    end

    class_methods do
      def has_shadow_attributes(*attributes)
        self.shadow_attributes = attributes
        attributes.each { |attribute| define_shadow_attribute_writer(attribute) }
      end

      def has_shadow_client(client)
        unless client.is_a?(ShadowClient)
          raise ArgumentError, "#{name}'s shadow client must be a Takamaru::ShadowClient, got #{client.inspect}"
        end

        self.shadow_client = client
      end

      def find_or_upsert_from_remote!(id)
        find_by(id: id) || upsert_from_remote!(id)
      end

      def find_or_upsert_from_remote_by!(attribute, value)
        find_by(attribute => value) || upsert_from_remote_by!(attribute, value)
      end

      def upsert_from_remote!(id)
        upsert_from_response!(shadow_client.find(id))
      end

      def upsert_from_remote_by!(attribute, value)
        upsert_from_response!(shadow_client.find_by(attribute, value))
      end

      def upsert_from_response!(response)
        parsed = shadow_client.parse(response)
        remote_attributes = parsed.fetch(:attributes).with_indifferent_access
        attributes = remote_attributes.slice(*shadow_attributes)
        # a response without updated_at is always applied, keeping the version already saved
        attributes[VERSION_COLUMN] = remote_attributes['updated_at'] if shadow_versioned? && remote_attributes['updated_at']

        initialize_record(parsed.fetch(:id), attributes)
      end

      # True when the table has the remote_updated_at column.
      def shadow_versioned?
        column_names.include?(VERSION_COLUMN)
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

      # In a savepoint, so that a RecordNotUnique can be retried inside an outer transaction too.
      def save_shadow_record(id, attributes)
        transaction(requires_new: true) do
          record = find_or_initialize_by(id: id)
          # the row lock serializes concurrent saves of the record: the version compared is the committed one
          record.lock! if record.persisted? && attributes.key?(VERSION_COLUMN)
          next record if stale_shadow_version?(record, attributes)

          record.allow_shadow_attributes_rewriting { record.update!(attributes) }
          record
        end
      end

      def stale_shadow_version?(record, attributes)
        return false unless attributes.key?(VERSION_COLUMN) && record[VERSION_COLUMN]

        type_for_attribute(VERSION_COLUMN).cast(attributes[VERSION_COLUMN]) < record[VERSION_COLUMN]
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
