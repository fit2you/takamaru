module Takamaru
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class PublishError < Error; end

  # Raised by a Takamaru::ShadowClient when the remote record does not exist.
  class RemoteRecordNotFound < Error; end
end
