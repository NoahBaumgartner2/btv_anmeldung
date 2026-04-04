class CreatePaymentSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_settings do |t|
      t.string :stripe_publishable_key
      t.text :stripe_secret_key_encrypted
      t.text :stripe_webhook_secret_encrypted
      t.string  :currency, default: "chf"
      t.boolean :active,   default: false, null: false

      t.timestamps
    end
  end
end
