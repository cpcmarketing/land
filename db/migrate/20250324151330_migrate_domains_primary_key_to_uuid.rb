class MigrateDomainsPrimaryKeyToUuid < ActiveRecord::Migration[7.0]
  def change
    # drop data checks as it relies on a column here
    # NOTE: This is commented out here as the view is just in BilldoctorWeb
    # drop_view :data_checks if connection.view_exists?(:data_checks)
    # add new primary key column
    add_column 'land.domains',  :domain_uuid, :uuid, default: 'gen_random_uuid()', null: false
    add_column 'land.referers', :domain_uuid, :uuid, default: 'gen_random_uuid()', null: false

    # create new foreign key column
    add_column 'land.visits', :domain_uuid, :uuid, null: true

    # populate new primary key column
    execute <<-SQL
      UPDATE land.visits
      SET domain_uuid = land.domains.domain_uuid
      FROM land.domains
      WHERE land.visits.domain_id = land.domains.domain_id;
    SQL

    # populate new primary key column
    execute <<-SQL
      UPDATE land.referers
      SET domain_uuid = land.domains.domain_uuid
      FROM land.domains
      WHERE land.referers.domain_id = land.domains.domain_id;
    SQL

    # remove old foreign key constraint
    execute 'ALTER TABLE land.referers DROP CONSTRAINT referers_domain_id_fkey'

    # remove primary key constraint
    execute 'ALTER TABLE land.domains DROP CONSTRAINT domains_pkey'
    rename_column 'land.domains', :domain_id, :domain_id_old
    change_column 'land.domains', :domain_id_old, :bigint, null: true
    # rename new primary key column
    rename_column 'land.domains', :domain_uuid, :domain_id

    # rename old foreign key column
    rename_column 'land.visits',   :domain_id, :domain_id_old
    rename_column 'land.referers', :domain_id, :domain_id_old
    change_column 'land.referers', :domain_id_old, :bigint, null: true
    # rename new foreign key column
    rename_column 'land.visits',   :domain_uuid, :domain_id
    rename_column 'land.referers', :domain_uuid, :domain_id

    # set new primary key column as primary key
    execute 'ALTER TABLE land.domains ADD PRIMARY KEY (domain_id);'

    # add new foreign key constraint
    add_foreign_key 'land.visits', 'land.domains',
                    index: true,
                    optional: true,
                    column: 'domain_id',
                    primary_key: 'domain_id',
                    name: 'visits_domain_id_fkey'

    add_foreign_key 'land.referers', 'land.domains',
                    index: true,
                    column: 'domain_id',
                    primary_key: 'domain_id',
                    name: 'referers_domain_id_fkey'

    # drop data checks as it relies on a column here
    # NOTE: This is commented out here as the view is just in BilldoctorWeb
    # create_view :data_checks unless connection.view_exists?(:data_checks)
  end
end
