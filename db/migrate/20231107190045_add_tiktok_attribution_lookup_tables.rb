class AddTiktokAttributionLookupTables < ActiveRecord::Migration[7.0]
  QUERY_PARAMS = %w[
      tiktok_click_id
      tiktok_pixel_cookie_id
  ]

  def up
    with_options schema: schema do |t|
      t.create_lookup_tables(*QUERY_PARAMS.map(&:pluralize))
    end

    add_column 'land.attributions', :tiktok_click_id, :integer
    add_column 'land.attributions', :tiktok_pixel_cookie_id, :integer
  end

  def down
    with_options schema: schema do |t|
      QUERY_PARAMS.each do |table|
        t.drop_table("#{schema}.#{table.pluralize}")
      end
    end

    remove_column 'land.attributions', :tiktok_click_id
    remove_column 'land.attributions', :tiktok_pixel_cookie_id
  end

  private

  def schema
    Land.config.schema
  end
end
