# Inhalt der versendeten Mail fürs Mail-Protokoll (Vorschau „was genau gesendet
# wurde“). Wird mit dem Eintrag nach der Aufbewahrungsfrist gelöscht.
class AddContentToMailLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :mail_logs, :html_body, :text
    add_column :mail_logs, :from_address, :string
  end
end
