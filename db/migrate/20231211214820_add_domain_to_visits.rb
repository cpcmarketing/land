class AddDomainToVisits < ActiveRecord::Migration[7.0]
  def change
    add_column 'land.visits', :domain_id, :integer
  end
end
