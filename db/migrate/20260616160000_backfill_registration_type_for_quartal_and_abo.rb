class BackfillRegistrationTypeForQuartalAndAbo < ActiveRecord::Migration[8.1]
  # Bisher leitete CoursesController#derive_registration_type die Modi "quartal"
  # und "abo" über den else-Zweig auf "semester" ab. Bestehende Kurse zeigten
  # daher fälschlich "Semesterkurs" statt "Quartalskurs" bzw. "Abo".
  def up
    execute "UPDATE courses SET registration_type = 'quartal' WHERE registration_mode = 'quartal'"
    execute "UPDATE courses SET registration_type = 'abo' WHERE registration_mode = 'abo'"
  end

  def down
    execute "UPDATE courses SET registration_type = 'semester' WHERE registration_mode IN ('quartal', 'abo')"
  end
end
