class AddPaymentMethodsToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :payment_methods, :string, array: true, default: ["card"], null: false
  end
end
