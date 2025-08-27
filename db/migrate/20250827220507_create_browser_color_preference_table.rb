class CreateBrowserColorPreferenceTable < ActiveRecord::Migration[7.2]
  def change
    create_table :browser_color_preferences, id: :uuid, default: 'gen_random_uuid()', primary_key: :browser_color_preference_id do |t|
      t.boolean :dark_mode, index: true
      t.boolean :light_mode, index: true
      t.boolean :no_preference, index: true

      t.timestamps
    end

    add_index :browser_color_preferences, [:dark_mode, :light_mode, :no_preference], name: 'index_browser_color_preferences_on_color_scheme_preferences'
  end
end
