class AddDeviceResolutionLookupTable < ActiveRecord::Migration[7.1]
  def change
    create_table "land.device_resolutions", id: :uuid, default: 'gen_random_uuid()', primary_key: :device_resolution_id do |t|
      t.string :device_resolution, index: true 
      t.integer :width, index: true
      t.integer :height, index: true
      t.string :orientation, index: true

      t.timestamps
    end

    add_index "land.device_resolutions", [:width, :height, :orientation], name: 'index_device_resolutions_on_dims_and_orientation'

    add_column "land.user_agents", :device_resolution_id, :uuid
    add_index "land.user_agents", :device_resolution_id, name: 'index_user_agents_on_device_resolution_id'

    add_column "land.browsers", :dark_mode, :boolean
    add_column "land.browsers", :light_mode, :boolean
    add_column "land.browsers", :no_preference, :boolean
    add_index "land.browsers", [:dark_mode, :light_mode, :no_preference], name: 'index_browsers_on_color_scheme_preferences'
  end
end
