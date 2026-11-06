FactoryBot.define do
  factory :commit_log, class: Takamaru::CommitLog do
    sequence(:exchange_name) { |n| "rails_application.exchange_#{n}" }
    sequence(:payload) { |n| { 'event' => 'update', 'id' => n } }
  end
end
