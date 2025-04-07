class AddApiUserAgentType < ActiveRecord::Migration[7.1]
  def up
    execute <<-SQL
    INSERT INTO land.user_agent_types (user_agent_type)
    VALUES ('api');
    SQL
  end

  def down
    execute <<-SQL
    DELETE FROM land.user_agent_types
    WHERE user_agent_type = 'api';
    SQL
  end
end
