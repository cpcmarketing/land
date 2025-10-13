class AddDeviceResolutionLookupTable < ActiveRecord::Migration[7.1]
  def change
    create_table 'land.device_resolutions', id: :uuid, default: 'gen_random_uuid()',
                                            primary_key: :device_resolution_id do |t|
      t.string :device_resolution, index: true
      t.integer :width, index: true
      t.integer :height, index: true
      t.string :orientation, index: true

      t.timestamps
    end

    add_index 'land.device_resolutions', %i[width height orientation],
              name: 'device_resolutions_width_height_orientation_idx', unique: true

    add_column 'land.user_agents', :device_resolution_id, :uuid
    add_foreign_key 'land.user_agents', 'land.device_resolutions', column: :device_resolution_id,
                                                                   primary_key: :device_resolution_id
  end
end
