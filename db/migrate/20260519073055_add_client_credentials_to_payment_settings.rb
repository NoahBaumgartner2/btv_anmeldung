class AddClientCredentialsToPaymentSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :payment_settings, :sumup_client_id, :string
    add_column :payment_settings, :sumup_client_secret_encrypted, :text
  end
end
