puts "👤 Erstelle Admin-Benutzer..."

noah = User.find_or_initialize_by(email: 'noah.baumgartner@gmx.ch')
noah.assign_attributes(
  password: 'password',
  password_confirmation: 'password',
  confirmed_at: Time.current,
  admin: true,
  privacy_accepted: true
)
noah.save!
