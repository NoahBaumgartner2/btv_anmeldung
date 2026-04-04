class CreateMailSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :mail_settings do |t|
      t.string  :smtp_host
      t.integer :smtp_port,               default: 587
      t.string  :smtp_username
      t.text    :smtp_password_encrypted
      t.string  :smtp_from_address
      t.string  :smtp_from_name
      t.string  :smtp_authentication,     default: "plain"
      t.boolean :smtp_enable_starttls,    default: true, null: false

      t.timestamps
    end
  end
end
