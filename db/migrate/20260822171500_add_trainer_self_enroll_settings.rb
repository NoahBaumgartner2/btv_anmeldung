class AddTrainerSelfEnrollSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :allows_trainer_self_enroll, :boolean, default: true, null: false

    create_table :feature_settings do |t|
      t.boolean :trainer_self_enroll_enabled, default: true, null: false
      t.timestamps
    end
  end
end
