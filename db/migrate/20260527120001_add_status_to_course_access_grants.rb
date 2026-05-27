class AddStatusToCourseAccessGrants < ActiveRecord::Migration[8.1]
  def change
    add_column :course_access_grants, :status, :string, default: "eingeladen", null: false
  end
end
