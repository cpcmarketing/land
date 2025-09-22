class CreateBrowserColorPreferenceTable < ActiveRecord::Migration[7.1]
  def change
    create_table 'land.browser_color_preferences', id: :uuid, default: 'gen_random_uuid()',
                                                   primary_key: :browser_color_preference_id do |t|
      t.boolean :dark_mode, index: true
      t.boolean :light_mode, index: true
      t.boolean :no_preference, index: true

      t.timestamps
    end

    add_index 'land.browser_color_preferences', %i[dark_mode light_mode no_preference],
              name: 'browser_color_preferences_dark_mode_light_mode_no_pref_idx', unique: true

    add_column 'land.user_agents', :browser_color_preference_id, :uuid
    add_foreign_key 'land.user_agents', 'land.browser_color_preferences', column: :browser_color_preference_id,
                                                                          primary_key: :browser_color_preference_id
  end
end
