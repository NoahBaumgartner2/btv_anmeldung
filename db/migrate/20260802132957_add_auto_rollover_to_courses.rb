class AddAutoRolloverToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :auto_rollover, :boolean, default: true, null: false
    add_column :courses, :rollover_notified_at, :datetime
  end
end
