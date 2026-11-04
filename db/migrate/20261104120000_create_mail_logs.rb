# Protokoll versendeter Mails. Bewusst ohne Fremdschlüssel: Kurse und Trainings werden
# gelöscht, der Eintrag soll trotzdem bleiben (Titel und Termin sind als Kopie gespeichert).
class CreateMailLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :mail_logs do |t|
      t.string :kind, null: false
      t.string :subject
      t.string :recipients, array: true, null: false, default: []
      t.string :audience
      t.bigint :course_id
      t.string :course_title
      t.bigint :training_session_id
      t.datetime :session_start
      t.bigint :participant_id
      t.string :participant_name
      t.bigint :trainer_ids, array: true, null: false, default: []
      t.datetime :created_at, null: false
    end
    add_index :mail_logs, :created_at
    add_index :mail_logs, :course_id
    add_index :mail_logs, :kind
    add_index :mail_logs, :participant_id
    add_index :mail_logs, :trainer_ids, using: :gin
  end
end
