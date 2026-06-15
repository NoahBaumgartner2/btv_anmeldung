class AddEmailNoteToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :email_note, :text
  end
end
