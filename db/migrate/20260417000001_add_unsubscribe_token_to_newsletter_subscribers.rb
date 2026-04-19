class AddUnsubscribeTokenToNewsletterSubscribers < ActiveRecord::Migration[8.1]
  def up
    add_column :newsletter_subscribers, :unsubscribe_token, :string
    add_index :newsletter_subscribers, :unsubscribe_token, unique: true

    NewsletterSubscriber.find_each do |subscriber|
      subscriber.update_column(:unsubscribe_token, SecureRandom.urlsafe_base64(32))
    end
  end

  def down
    remove_column :newsletter_subscribers, :unsubscribe_token
  end
end
