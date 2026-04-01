class CreateTrainingSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :training_sessions do |t|
      t.references :course, null: false, foreign_key: true
      t.datetime :start_time
      t.datetime :end_time
      t.boolean :is_canceled

      t.timestamps
    end
  end
end
