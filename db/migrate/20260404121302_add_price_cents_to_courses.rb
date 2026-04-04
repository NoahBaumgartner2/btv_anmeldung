class AddPriceCentsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :price_cents, :integer
  end
end
