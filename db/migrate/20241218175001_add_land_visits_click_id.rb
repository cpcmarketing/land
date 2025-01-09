class AddLandVisitsClickId < ActiveRecord::Migration[7.0]
  def change
    add_column 'land.visits', :click_id, :text
  end
end
