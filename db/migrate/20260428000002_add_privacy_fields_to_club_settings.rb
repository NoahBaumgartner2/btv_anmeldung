class AddPrivacyFieldsToClubSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :club_settings, :contact_street,        :string
    add_column :club_settings, :contact_zip,           :string
    add_column :club_settings, :contact_city,          :string
    add_column :club_settings, :contact_email,         :string
    add_column :club_settings, :contact_website,       :string
    add_column :club_settings, :contact_phone,         :string
    add_column :club_settings, :legal_form,            :string
    add_column :club_settings, :responsible_name,      :string
    add_column :club_settings, :responsible_function,  :string
    add_column :club_settings, :privacy_officer_name,  :string
    add_column :club_settings, :privacy_officer_email, :string
    add_column :club_settings, :hosting_provider,      :string
    add_column :club_settings, :hosting_country,       :string
    add_column :club_settings, :smtp_provider,         :string
    add_column :club_settings, :payment_provider,      :string, default: "SumUp"
  end
end
