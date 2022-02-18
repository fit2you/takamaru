FactoryBot.define do
  factory :commit_log, class: Takamaru::CommitLog do
    sequence(:exchange_name) { |n| "exchange_name_#{n}" }
    sequence(:payload) { |n| { "payload_#{n}" => "payload_#{n}" } }
  end
end
