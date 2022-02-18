module Takamaru
  module CommitLoggable
    extend ActiveSupport::Concern

    attr_reader :do_not_log_commit

    included do
      after_commit :mine_commit_logs
      after_create :publish_create_message
      after_destroy :publish_destroy_message
      after_update :publish_update_message
    end

    def without_commit_log(&block)
      @do_not_log_commit = true
      yield self
      @do_not_log_commit = false
    end

    private

    %i[create destroy update].each do |event|
      define_method "publish_#{event}_message" do
        log_commit(event) unless do_not_log_commit
      end
    end

    def log_commit(event)
      exchange_name = "#{Rails.application.class.parent_name.underscore}_#{self.class.name.tableize}"
      Takamaru::CommitLog.create!(exchange_name: exchange_name, payload: { id: id, event: event })
    end

    def mine_commit_logs
      Takamaru::CommitLogMinerJob.perform_later
    end
  end
end
