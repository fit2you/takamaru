module Takamaru
  class ShadowModelConsumer < ApplicationConsumer
    def consume
      queue.subscribe do |payload|
        send_from_payload(payload)
      rescue StandardError => exception
        UnhandledMessageLog.create!(consumer: self.class.name, payload: payload)
        Rollbar.critical(exception)
      end
    end

    private

    %i[create destroy update].each do |event|
      define_method("consume_#{event}") do |id|
        job_class = class_name.gsub('Consumer', 'Job').constantize
        job_class.perform_later(id, event.to_s)
      end
    end

    def class_name
      self.class.name
    end

    def send_from_payload(payload)
      parsed_payload = JSON.parse(payload)
      event = parsed_payload.fetch('event')
      id = parsed_payload.fetch('id')
      puts "#{class_name} consuming #{event} for #{id}"
      send("consume_#{event}", id)
    end
  end
end
