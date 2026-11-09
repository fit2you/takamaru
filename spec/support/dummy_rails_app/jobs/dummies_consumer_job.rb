class DummiesConsumerJob < ActiveJob::Base
  def perform(id, event, _metadata = {})
    if %w[create update].include?(event)
      Dummy.upsert_from_remote!(id)
    elsif event == 'destroy'
      Dummy.find_by(id: id)&.destroy!
    end
  end
end
