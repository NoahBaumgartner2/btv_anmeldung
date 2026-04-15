class CreateInfomaniakSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :infomaniak_settings do |t|
      t.text    :api_token_encrypted
      t.string  :mailing_list_id
      t.string  :base_url
      t.boolean :active, default: false, null: false

      t.timestamps
    end
  end
end
