class AddNotifyAdminOnParticipantProfileChangeToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :notify_admin_on_participant_profile_change, :boolean, default: false, null: false
  end
end
