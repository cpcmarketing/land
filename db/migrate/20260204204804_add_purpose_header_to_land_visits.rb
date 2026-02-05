class AddPurposeHeaderToLandVisits < ActiveRecord::Migration[7.1]
  def change
    add_column 'land.visits', :http_purpose_header, :string, null: true
    add_index 'land.visits', :http_purpose_header

    add_column 'land.visits', :http_sec_purpose_header, :string, null: true
    add_index 'land.visits', :http_sec_purpose_header
  end
end
