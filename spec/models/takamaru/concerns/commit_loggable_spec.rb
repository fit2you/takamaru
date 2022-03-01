require 'rails_helper'

RSpec.describe(Takamaru::CommitLoggable) do
  let(:dummy_commit_loggable) { DummyCommitLoggable.new }

  %i[create destroy update].each do |event|
    describe(".publish_#{event}_message") do
      describe 'with commit log' do
        it('calls log_commit once') do
          expect(dummy_commit_loggable).to(receive('log_commit').with(event).once)

          dummy_commit_loggable.send(:"publish_#{event}_message")
        end
      end

      describe 'without commit log' do
        it('does not call log_commit') do
          expect(dummy_commit_loggable).to_not(receive('log_commit'))

          dummy_commit_loggable.without_commit_log do |model|
            model.send(:"publish_#{event}_message")
          end
        end
      end
    end
  end

  describe('with an existing commit log') do
    before(:each) do
      expect(dummy_commit_loggable).to(receive('publish_create_message').once)
      expect(dummy_commit_loggable).to(receive('mine_commit_logs').once)

      dummy_commit_loggable.save!
    end

    describe('after_destroy') do
      it('calls publish_destroy_message once') do
        expect(dummy_commit_loggable).to(receive('publish_destroy_message').once)
        expect(dummy_commit_loggable).to(receive('mine_commit_logs').once)

        dummy_commit_loggable.destroy
      end
    end

    describe('after_update') do
      it('calls publish_update_message once') do
        expect(dummy_commit_loggable).to(receive('publish_update_message').once)
        expect(dummy_commit_loggable).to(receive('mine_commit_logs').once)

        dummy_commit_loggable.name = 'foo'
        dummy_commit_loggable.save!
      end
    end
  end

  describe('.log_commit') do
    let(:rails_application_name) { 'RailsApplication' }
    let(:exchange_name) { "#{rails_application_name.underscore}.#{dummy_commit_loggable.class.name.tableize}" }
    let(:payload) { { id: dummy_commit_loggable.id, event: :create } }

    it('enwueues Takamaru::CommitLogMinerJob') do
      allow(Rails.application).to(receive('class')).and_return(double(name: '', parent_name: rails_application_name))
      expect(Takamaru::CommitLog).to(receive(:create!).with(exchange_name: exchange_name, payload: payload).once)

      dummy_commit_loggable.send(:log_commit, :create)
    end
  end

  describe('.mine_commit_logs') do
    it('enwueues Takamaru::CommitLogMinerJob') do
      expect(Takamaru::CommitLogMinerJob).to(receive(:perform_later).once)

      dummy_commit_loggable.send(:mine_commit_logs)
    end
  end
end
