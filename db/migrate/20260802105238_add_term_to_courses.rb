class AddTermToCourses < ActiveRecord::Migration[8.1]
  def change
    add_reference :courses, :term, null: true, foreign_key: true
  end
end
