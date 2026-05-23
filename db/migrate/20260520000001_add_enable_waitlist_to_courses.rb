class AddEnableWaitlistToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :enable_waitlist, :boolean, default: true, null: false
  end
end
