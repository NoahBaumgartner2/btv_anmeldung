class CreateAgeExemptions < ActiveRecord::Migration[8.1]
  def change
    create_table :age_exemptions do |t|
      t.references :participant, null: false, foreign_key: true
      t.references :course, null: false, foreign_key: true
      t.references :granted_by, foreign_key: { to_table: :users }
      t.text :note

      t.timestamps
    end

    add_index :age_exemptions, [ :participant_id, :course_id ], unique: true,
      name: "index_age_exemptions_unique_per_participant_course"
  end
end
