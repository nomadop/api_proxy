class AddDistanceAndDurationToRoutes < ActiveRecord::Migration
  def change
    add_column :routes, :distance, :integer
    add_column :routes, :duration, :integer
  end
end
