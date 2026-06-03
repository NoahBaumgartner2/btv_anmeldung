class AddPhotoConsentAcceptedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :photo_consent_accepted_at, :datetime
  end
end
