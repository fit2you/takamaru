ActiveRecord::Schema.define(version: 20200904110000) do
  create_table 'dummy_models' do |t|
  end

  create_table 'takamaru_commit_logs' do |t|
    t.string(:exchange_name, null: false)
    t.json(:payload, null: false)
    t.timestamps(null: false)
  end
end
