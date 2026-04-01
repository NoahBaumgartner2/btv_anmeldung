class CreateTrainers < ActiveRecord::Migration[8.1]
  def change
    create_table :trainers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :phone

      t.timestamps
    end
  end
end
