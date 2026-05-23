class CreateCourseAccessGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :course_access_grants do |t|
      t.references :course, null: false, foreign_key: true
      t.references :user,   null: false, foreign_key: true
      t.timestamps
    end
    add_index :course_access_grants, [ :course_id, :user_id ], unique: true
  end
end
