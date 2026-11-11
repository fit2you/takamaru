# A commit loggable model adding attributes to the payload of its commit logs.
class DummyRoleCommitLoggable < ActiveRecord::Base
  self.table_name = 'dummy_commit_loggables'

  include Takamaru::CommitLoggable

  enum :role, { vendor: 0, dealer: 1 }

  commit_log_attributes :role, :name
end
