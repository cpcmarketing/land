class AddUnalteredIngressUrlToVisits < ActiveRecord::Migration[7.0]
  def change
    add_column 'land.visits', :unaltered_ingress_url, :text
  end
end
