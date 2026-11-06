module Takamaru
  # Contract of the client of a shadow model: subclass it in the application and implement #find and #find_by.
  # Takamaru does not know how the remote service is reached (HTTP library, URLs, authentication).
  #
  #   class UsersShadowClient < Takamaru::ShadowClient
  #     def find(id)
  #       HurricaneClient.user(id)
  #     end
  #
  #     def find_by(attribute, value)
  #       HurricaneClient.user_by(attribute, value)
  #     end
  #   end
  #
  #   class User < ApplicationRecord
  #     include Takamaru::Shadowable
  #
  #     has_shadow_client UsersShadowClient.new
  #   end
  class ShadowClient
    # Returns the response of the remote record with the given id, in the format read by #parse.
    # Raises Takamaru::RemoteRecordNotFound when the record does not exist.
    def find(id)
      raise NotImplementedError, "#{self.class.name} must implement #find(id)"
    end

    # Returns the response of the remote record whose attribute has the given value, in the format read by #parse.
    # Raises Takamaru::RemoteRecordNotFound when the record does not exist.
    def find_by(attribute, value)
      raise NotImplementedError, "#{self.class.name} must implement #find_by(attribute, value)"
    end

    # Turns a response of #find or #find_by into { id:, attributes: }; attributes keys must match the model ones.
    # Defaults to a parsed JSON:API document: override it for other formats.
    def parse(response)
      JsonApiParser.call(response)
    end
  end
end
