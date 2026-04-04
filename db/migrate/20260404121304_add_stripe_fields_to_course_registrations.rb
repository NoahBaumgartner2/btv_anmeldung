class AddStripeFieldsToCourseRegistrations < ActiveRecord::Migration[8.1]
  def change
    add_column :course_registrations, :stripe_payment_intent_id, :string
    add_column :course_registrations, :stripe_session_id, :string
    add_index  :course_registrations, :stripe_session_id
    add_index  :course_registrations, :stripe_payment_intent_id
  end
end
