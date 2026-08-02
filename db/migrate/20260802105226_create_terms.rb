class CreateTerms < ActiveRecord::Migration[8.1]
  def change
    create_table :terms do |t|
      t.string :name
      t.date :start_date
      t.date :end_date

      t.timestamps
    end
    add_index :terms, :name, unique: true
  end
end
