class AddTokenExpiresAtToPaymentSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :payment_settings, :sumup_token_expires_at, :datetime
  end
end
