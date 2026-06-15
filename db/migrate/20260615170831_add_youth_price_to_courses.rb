class AddYouthPriceToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :youth_price_cents, :integer
    add_column :courses, :youth_max_age, :integer, default: 20
  end
end
