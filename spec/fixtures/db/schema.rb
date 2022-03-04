ActiveRecord::Schema.define(version: 20200904110000) do
  create_table 'dummy_commit_loggables' do |t|
    t.string(:name)
    t.timestamps(null: false)
  end

  create_table 'dummies' do |t|
    t.string(:attribute_1)
    t.string(:attribute_2)
    t.timestamps(null: false)
  end

  create_table 'takamaru_commit_logs' do |t|
    t.string(:exchange_name, null: false)
    t.json(:payload, null: false)
    t.timestamps(null: false)
  end

  create_table 'takamaru_unhandled_message_logs' do |t|
    t.string(:consumer, null: false)
    t.json(:payload, null: false)
    t.timestamps(null: false)
  end
end
