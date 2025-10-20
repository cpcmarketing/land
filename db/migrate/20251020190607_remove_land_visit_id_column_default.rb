class RemoveLandVisitIdColumnDefault < ActiveRecord::Migration[7.1]
  def change
    change_column_default 'land.visits', :visit_id, nil
  end
end
