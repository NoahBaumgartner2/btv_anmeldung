class CreateClubSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :club_settings do |t|
      t.string :club_name
      t.string :primary_color
      t.string :secondary_color

      t.timestamps
    end
  end
end
