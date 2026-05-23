class AddLocationAddressToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :location_address, :string
  end
end
