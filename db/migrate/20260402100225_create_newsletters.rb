class CreateNewsletters < ActiveRecord::Migration[8.1]
  def change
    create_table :newsletters do |t|
      t.string :title
      t.string :subject
      t.text :body_html
      t.string :status
      t.datetime :sent_at
      t.integer :recipients_count

      t.timestamps
    end
  end
end
