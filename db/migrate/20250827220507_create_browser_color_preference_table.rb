class CreateBrowserColorPreferenceTable < ActiveRecord::Migration[7.2]
  def change
    create_table "land.browser_color_preferences", id: :uuid, default: 'gen_random_uuid()', primary_key: :browser_color_preference_id do |t|
      t.boolean :dark_mode, index: true
      t.boolean :light_mode, index: true
      t.boolean :no_preference, index: true

      t.timestamps
    end

    add_index "land.browser_color_preferences", [:dark_mode, :light_mode, :no_preference], name: 'index_browser_color_preferences_on_color_scheme_preferences'

    add_column "land.user_agents", :browser_color_preference_id, :uuid
    add_index "land.user_agents", :browser_color_preference_id, name: 'index_user_agents_on_browser_color_preference_id'
  end
end
