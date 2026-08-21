require_relative "application_system_test_case"

class CourseCategoriesTest < ApplicationSystemTestCase
  test "Bild-Upload per Datei-Auswahl wird sofort gespeichert (real browser, CSP aktiv)" do
    admin = users(:admin)
    Course.new(title: "System-Test", category: "SystemTestKategorie",
      registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
      .save!(validate: false)
    login_as admin, scope: :user

    visit course_categories_path
    within(find("div[data-controller='modal']", text: "SystemTestKategorie")) do
      attach_file "course_category[image]", Rails.root.join("test/fixtures/files/test_image.png")
    end

    # redirect_to lädt eine komplett neue Seite (kein Turbo-Stream-Update) – daher
    # den Zeilen-Container hier neu suchen statt die alte Referenz weiterzuverwenden.
    # Capybaras Standard-Retry wartet dabei auf die Navigation. Das grau-gestrichelte
    # Platzhalter-Div wird durch ein <img> ersetzt, sobald das Bild angehängt ist –
    # belegt, dass die Auswahl allein (ohne separaten Klick) den Upload auslöst.
    within(find("div[data-controller='modal']", text: "SystemTestKategorie")) do
      assert_selector "img"
    end

    category = CourseCategory.find_by!(name: "SystemTestKategorie")
    assert category.image.attached?, "Bild muss nach dem Auswählen ohne separaten Klick automatisch hochgeladen werden"
  end
end
