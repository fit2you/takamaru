module Takamaru
  class Error < StandardError; end

  class ConfigurationError < Error; end

  # Base class of the errors that go away by themselves, such as an unreachable broker or job backend: error trackers
  # group them by class, apart from bugs. The original error, when there is one, is the cause.
  class TransientError < Error; end

  # RabbitMQ is unreachable or did not confirm a message. The commit logs stay pending and are published again later.
  class PublishError < TransientError; end

  # The job backend (e.g. Redis for Resque) did not enqueue a job.
  class EnqueueError < TransientError; end

  # Raised by a Takamaru::ShadowClient when the remote record does not exist.
  class RemoteRecordNotFound < Error; end
end
