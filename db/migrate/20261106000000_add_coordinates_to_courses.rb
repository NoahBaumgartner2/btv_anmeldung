# Koordinaten des Kursorts für die Nähe in den Kursempfehlungen. Gefüllt von
# GeocodeCoursesJob; ohne Koordinaten zählt die Nähe beim Kurs einfach nicht.
class AddCoordinatesToCourses < ActiveRecord::Migration[8.1]
  def change
    add_column :courses, :latitude, :float
    add_column :courses, :longitude, :float
  end
end
