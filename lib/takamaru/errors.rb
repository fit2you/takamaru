module Takamaru
  class Error < StandardError; end

  class ConfigurationError < Error; end

  class PublishError < Error; end
end
