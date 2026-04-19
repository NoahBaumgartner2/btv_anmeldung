class AddAppHostToMailSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :mail_settings, :app_host, :string
  end
end
