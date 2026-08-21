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
    category_row = find("div[data-controller='modal']", text: "SystemTestKategorie")
    within(category_row) do
      attach_file "course_category[image]", Rails.root.join("test/fixtures/files/test_image.png"), visible: false
    end

    assert_text "wurde gespeichert"
    category = CourseCategory.find_by!(name: "SystemTestKategorie")
    assert category.image.attached?, "Bild muss nach dem Auswählen ohne separaten Klick automatisch hochgeladen werden"
  end
end
