module Land
  class UserAgentType < ApplicationRecord
    include TableName

    lookup_by :user_agent_type, cache: 50, find_or_create: true

    has_many :user_agents
  end
end
