# Trainer, die vor Einführung der Selbstanmeldung erfasst wurden, haben ihren
# Selbst-Teilnehmer erst beim nächsten Speichern des Profils bekommen. Ohne ihn
# zeigt die Kursseite "Profil unvollständig", obwohl das Profil vollständig ist.
class BackfillTrainerSelfParticipants < ActiveRecord::Migration[8.1]
  def up
    Trainer.where(self_participant_id: nil).find_each do |trainer|
      # Konten mit Kindern auslassen: der neue Datensatz erschiene in ihrer Familienansicht.
      others = Participant.where(user_id: trainer.user_id)
                          .where.not(first_name: trainer.first_name, last_name: trainer.last_name, date_of_birth: trainer.date_of_birth)
      next if others.exists?

      trainer.sync_self_participant!
    end
  end

  def down
    # Bewusst leer: die Datensätze können inzwischen Anmeldungen haben.
  end
end
