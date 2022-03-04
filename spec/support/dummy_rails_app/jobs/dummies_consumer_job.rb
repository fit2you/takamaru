class DummiesConsumerJob < ActiveJob::Base
  attr_reader :id

  def perform(id, event)
    if %w[create update].include?(event)
      Dummy.upsert_from_remote!(id)
    elsif event == 'destroy'
      Dummy.find_by_id(id)&.destroy!
    else
      raise "Unknown event: #{event}"
    end
  end
end
