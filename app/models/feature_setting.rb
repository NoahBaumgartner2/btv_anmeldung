# Globale Ein/Aus-Schalter für einzelne Funktionen der App (Single-Row wie
# ClubSetting/MailSetting). Aktuell nur trainer_self_enroll_enabled – weitere
# Feature-Flags können hier ergänzt werden, ohne eine neue Tabelle zu brauchen.
class FeatureSetting < ApplicationRecord
  def self.current
    first_or_create!
  end
end
