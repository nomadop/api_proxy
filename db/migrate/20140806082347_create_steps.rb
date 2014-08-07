class CreateSteps < ActiveRecord::Migration
  def change
    create_table :steps do |t|
      t.integer :route_id
      t.integer :step_number
      t.integer :distance
      t.integer :duration
      t.string :start_location
      t.string :end_location
      t.text :path
      t.text :transit_details
      t.text :html_instructions
      t.string :travel_mode
      t.string :map_uid

      t.timestamps
    end
  end
end
