class AddDiscountFieldsToCoursesAndRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :discounts_enabled, :boolean, default: false, null: false
    add_column :courses, :sibling_price_cents, :integer
    add_column :courses, :second_course_price_cents, :integer

    add_column :course_registrations, :applied_price_cents, :integer
    add_column :course_registrations, :applied_discount, :string
  end
end
