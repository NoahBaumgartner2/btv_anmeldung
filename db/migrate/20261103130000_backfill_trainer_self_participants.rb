# Trainer, die vor Einführung der Selbstanmeldung erfasst wurden, haben ihren
# Selbst-Teilnehmer erst beim nächsten Speichern des Profils bekommen. Ohne ihn
# zeigt die Kursseite "Profil unvollständig", obwohl das Profil vollständig ist.
class BackfillTrainerSelfParticipants < ActiveRecord::Migration[8.1]
  def up
    Trainer.where(self_participant_id: nil).find_each(&:sync_self_participant!)
  end

  def down
    # Bewusst leer: die Datensätze können inzwischen Anmeldungen haben.
  end
end
