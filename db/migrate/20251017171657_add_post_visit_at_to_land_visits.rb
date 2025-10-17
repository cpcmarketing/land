class AddPostVisitAtToLandVisits < ActiveRecord::Migration[7.1]
  def change
    add_column 'land.visits', :post_visit_at, :timestamptz
  end
end
