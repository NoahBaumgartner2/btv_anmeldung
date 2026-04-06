namespace :fix do
  desc "Setzt ausstehende Anmeldungen für kostenlose Kurse auf bestätigt oder warteliste"
  task free_course_registrations: :environment do
    affected = CourseRegistration.where(status: "ausstehend").select { |reg| reg.course.price_cents.to_i == 0 }

    if affected.empty?
      puts "Keine betroffenen Anmeldungen gefunden."
      next
    end

    affected.each do |reg|
      confirmed = reg.course.course_registrations.where(status: "bestätigt").count
      max       = reg.course.max_participants
      new_status = (max.present? && confirmed >= max) ? "warteliste" : "bestätigt"
      reg.update!(status: new_status, payment_cleared: false)
      puts "Fixed registration #{reg.id} (Kurs: #{reg.course.title}) → #{new_status}"
    end

    puts "Fertig. #{affected.size} Anmeldung(en) korrigiert."
  end
end
