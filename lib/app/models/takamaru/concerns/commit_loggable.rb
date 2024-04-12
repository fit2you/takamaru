# rubocop:disable Style/ClassVars
module Takamaru
  module CommitLoggable
    extend ActiveSupport::Concern

    attr_reader :do_not_log_commit

    included do
      after_commit :mine_commit_logs
      after_create :publish_create_message
      after_destroy :publish_destroy_message
      after_update :publish_update_message

      class_variable_set(:@@takamaru_class_name, name.tableize)

      class << self
        def override_takamaru_class_name(class_name)
          class_variable_set(:@@takamaru_class_name, class_name)
        end
      end
    end

    def without_commit_log(&block)
      @do_not_log_commit = true
      yield self
      @do_not_log_commit = false
    end

    private

    %i[create destroy update].each do |event|
      define_method "publish_#{event}_message" do
        log_commit(event) if !do_not_log_commit && (event != :update || changed?)
      end
    end

    def log_commit(event)
      exchange_name = "#{Takamaru.rails_application_name}.#{self.class.class_variable_get(:@@takamaru_class_name)}"
      @commit_log_id = Takamaru::CommitLog.create!(exchange_name: exchange_name, payload: { id: id, event: event }).id
    end

    def mine_commit_logs
      Takamaru::CommitLogMinerJob.perform_later(@commit_log_id)
    end
  end
end

# rubocop:enable Style/ClassVars
