class AddPurposeHeaderToLandVisits < ActiveRecord::Migration[7.1]
  def change
    add_column 'land.visits', :purpose_header, :string, null: true
    add_index 'land.visits', :purpose_header
  end
end
