class CreateNewsletterSubscribers < ActiveRecord::Migration[8.1]
  def change
    create_table :newsletter_subscribers do |t|
      t.string :email, null: false
      t.string :name
      t.string :status, null: false, default: "subscribed"
      t.string :source, default: "manual"

      t.timestamps
    end
    add_index :newsletter_subscribers, :email, unique: true
  end
end
