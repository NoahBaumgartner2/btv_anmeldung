class MigrateStripeToSumup < ActiveRecord::Migration[8.1]
  def change
    # payment_settings: Stripe-Spalten durch SumUp-Äquivalente ersetzen
    rename_column :payment_settings, :stripe_publishable_key,        :sumup_api_key
    rename_column :payment_settings, :stripe_secret_key_encrypted,   :sumup_access_token_encrypted
    rename_column :payment_settings, :stripe_webhook_secret_encrypted, :sumup_merchant_code

    # sumup_merchant_code ist ein Klartext-String (kein verschlüsselter Blob)
    change_column :payment_settings, :sumup_merchant_code, :string
    change_column :payment_settings, :sumup_access_token_encrypted, :text

    # course_registrations: Stripe-Felder durch SumUp-Felder ersetzen
    remove_index  :course_registrations, :stripe_session_id
    remove_index  :course_registrations, :stripe_payment_intent_id

    rename_column :course_registrations, :stripe_session_id,         :sumup_checkout_id
    rename_column :course_registrations, :stripe_payment_intent_id,  :sumup_transaction_id

    add_index :course_registrations, :sumup_checkout_id
    add_index :course_registrations, :sumup_transaction_id
  end
end
