class CreateRoutes < ActiveRecord::Migration
  def change
    create_table :routes do |t|
      t.integer :direction_id
      t.string :origin
      t.string :destination
      t.text :path
      t.text :markers
      t.string :map_uid

      t.timestamps
    end
  end
end
