class AddPostVisitAtToLandVisits < ActiveRecord::Migration[7.1]
  def change
    add_column 'land.visits', :post_visit_at, :datetime
  end
end
