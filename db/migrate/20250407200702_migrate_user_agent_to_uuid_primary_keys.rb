class MigrateUserAgentToUuidPrimaryKeys < ActiveRecord::Migration[7.1]
  def change
    # create and generate uuid columns
    add_column 'land.user_agents', :user_agent_uuid, :uuid, default: 'gen_random_uuid()', null: false

    # create and generate new uuid columns in lookup tables
    add_column 'land.user_agent_types', :user_agent_type_uuid, :uuid, default: 'gen_random_uuid()', null: false
    add_column 'land.devices',          :device_uuid,          :uuid, default: 'gen_random_uuid()', null: false
    add_column 'land.platforms',        :platform_uuid,        :uuid, default: 'gen_random_uuid()', null: false
    add_column 'land.browsers',         :browser_uuid,         :uuid, default: 'gen_random_uuid()', null: false

    # create columns to be populated by generated uuids
    add_column 'land.user_agents', :user_agent_type_uuid, :uuid, null: true
    add_column 'land.user_agents', :device_uuid,          :uuid, null: true
    add_column 'land.user_agents', :platform_uuid,        :uuid, null: true
    add_column 'land.user_agents', :browser_uuid,         :uuid, null: true

    # add new foreign key
    add_column 'land.visits', :user_agent_uuid, :uuid, null: true

    # populate new primary key columns
    execute <<-SQL
      UPDATE land.visits
      SET user_agent_uuid = land.user_agents.user_agent_uuid
      FROM land.user_agents
      WHERE land.visits.user_agent_id = land.user_agents.user_agent_id;
    SQL

    execute <<-SQL
      UPDATE land.user_agents
      SET user_agent_type_uuid = land.user_agents.user_agent_type_uuid
      FROM land.user_agent_types
      WHERE land.user_agents.user_agent_type_id = land.user_agent_types.user_agent_type_id;
    SQL

    execute <<-SQL
      UPDATE land.user_agents
      SET device_uuid = land.devices.device_uuid
      FROM land.devices
      WHERE land.user_agents.device_id = land.devices.device_id;
    SQL

    execute <<-SQL
      UPDATE land.user_agents
      SET platform_uuid = land.platforms.platform_uuid
      FROM land.platforms
      WHERE land.user_agents.platform_id = land.platforms.platform_id;
    SQL

    execute <<-SQL
      UPDATE land.user_agents
      SET browser_uuid = land.browsers.browser_uuid
      FROM land.browsers
      WHERE land.user_agents.browser_id = land.browsers.browser_id;
    SQL

    # remove old foreign key constraint
    execute 'ALTER TABLE land.user_agents DROP CONSTRAINT user_agents_browser_id_fkey'
    execute 'ALTER TABLE land.user_agents DROP CONSTRAINT user_agents_device_id_fkey'
    execute 'ALTER TABLE land.user_agents DROP CONSTRAINT user_agents_platform_id_fkey'
    execute 'ALTER TABLE land.user_agents DROP CONSTRAINT user_agents_user_agent_type_id_fkey'
    execute 'ALTER TABLE land.visits      DROP CONSTRAINT visits_user_agent_id_fkey'

    # remove primary key constraints
    execute 'ALTER TABLE land.browsers         DROP CONSTRAINT browsers_pkey'
    execute 'ALTER TABLE land.devices          DROP CONSTRAINT devices_pkey'
    execute 'ALTER TABLE land.platforms        DROP CONSTRAINT platforms_pkey'
    execute 'ALTER TABLE land.user_agent_types DROP CONSTRAINT user_agent_types_pkey'
    execute 'ALTER TABLE land.user_agents      DROP CONSTRAINT user_agents_pkey'

    # rename old foreign keys
    rename_column 'land.user_agents',      :browser_id,           :browser_id_old
    rename_column 'land.user_agents',      :device_id,            :device_id_old
    rename_column 'land.user_agents',      :platform_id,          :platform_id_old
    rename_column 'land.user_agents',      :user_agent_type_id,   :user_agent_type_id_old
    rename_column 'land.visits',           :user_agent_id,        :user_agent_id_old

    rename_column 'land.browsers',         :browser_id,           :browser_id_old
    rename_column 'land.devices',          :device_id,            :device_id_old
    rename_column 'land.platforms',        :platform_id,          :platform_id_old
    rename_column 'land.user_agent_types', :user_agent_type_id,   :user_agent_type_id_old
    rename_column 'land.user_agents',      :user_agent_id,        :user_agent_id_old

    # create columns to be populated by generated uuids
    rename_column 'land.user_agents',      :browser_uuid,         :browser_id
    rename_column 'land.user_agents',      :device_uuid,          :device_id
    rename_column 'land.user_agents',      :platform_uuid,        :platform_id
    rename_column 'land.user_agents',      :user_agent_type_uuid, :user_agent_type_id
    rename_column 'land.visits',           :user_agent_uuid,      :user_agent_id

    rename_column 'land.browsers',         :browser_uuid,         :browser_id
    rename_column 'land.devices',          :device_uuid,          :device_id
    rename_column 'land.platforms',        :platform_uuid,        :platform_id
    rename_column 'land.user_agent_types', :user_agent_type_uuid, :user_agent_type_id
    rename_column 'land.user_agents',      :user_agent_uuid,      :user_agent_id

    # set new primary key columns as primary keys
    execute 'ALTER TABLE land.browsers         ADD PRIMARY KEY (browser_id);'
    execute 'ALTER TABLE land.devices          ADD PRIMARY KEY (device_id);'
    execute 'ALTER TABLE land.platforms        ADD PRIMARY KEY (platform_id);'
    execute 'ALTER TABLE land.user_agent_types ADD PRIMARY KEY (user_agent_type_id);'
    execute 'ALTER TABLE land.user_agents      ADD PRIMARY KEY (user_agent_id);'

    # add new foreign key constraints
    add_foreign_key 'land.user_agents', 'land.user_agent_types',
                    index: true,
                    column: 'user_agent_type_id',
                    primary_key: 'user_agent_type_id',
                    name: 'user_agents_user_agent_type_id_fkey'

    add_foreign_key 'land.user_agents', 'land.devices',
                    index: true,
                    column: 'device_id',
                    primary_key: 'device_id',
                    name: 'user_agents_device_id_fkey'

    add_foreign_key 'land.user_agents', 'land.platforms',
                    index: true,
                    column: 'platform_id',
                    primary_key: 'platform_id',
                    name: 'user_agents_platform_id_fkey'

    add_foreign_key 'land.visits', 'land.user_agents',
                    index: true,
                    column: 'user_agent_id',
                    primary_key: 'user_agent_id',
                    name: 'visits_user_agent_id_fkey'

    # add back indexes
    add_index 'land.user_agents', :user_agent_id
    add_index 'land.user_agents', :user_agent_id_old
    add_index 'land.user_agents', :user_agent_type_id
    add_index 'land.user_agents', :device_id
    add_index 'land.user_agents', :platform_id
    add_index 'land.user_agents', :browser_id
    add_index 'land.visits',      :user_agent_id
  end
end
