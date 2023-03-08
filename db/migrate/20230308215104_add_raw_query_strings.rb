class AddRawQueryStrings < ActiveRecord::Migration[7.0]
  def change
    add_column :visits, :raw_query_strings, :text
  end
end
