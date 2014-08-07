class CreateDirections < ActiveRecord::Migration
  def change
    create_table :directions do |t|
      t.string :origin
      t.string :destination
      t.string :status, default: 'New'
      t.text :options

      t.timestamps
    end
  end
end
