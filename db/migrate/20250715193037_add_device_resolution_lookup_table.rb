class AddDeviceResolutionLookupTable < ActiveRecord::Migration[7.1]
  def up
    create_table :device_resolutions, id: :uuid, default: 'gen_random_uuid()', primary_key: :device_resolution_id do |t|
      t.string :device_resolution, null: false, index: true 
      t.integer :width, null: false, index: true
      t.integer :height, null: false, index: true
      t.timestamps null: false
    end

    add_column "land.user_agents", :device_resolution_id, :uuid
    add_index "land.user_agents", :device_resolution_id, name: 'index_user_agents_on_device_resolution_id'

    add_column "land.devices", :device_resolution_id, :uuid
    add_index "land.devices", :device_resolution_id, name: 'index_devices_on_device_resolution_id'
  end

  def down
    remove_index "land.user_agents", name: 'index_user_agents_on_device_resolution_id'
    remove_column "land.user_agents", :device_resolution_id

    remove_index "land.devices", name: 'index_devices_on_device_resolution_id'
    remove_column "land.devices", :device_resolution_id

    drop_table :device_resolutions
  end
end