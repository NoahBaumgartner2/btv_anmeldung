require_relative "application_system_test_case"

class CourseCategoriesTest < ApplicationSystemTestCase
  test "trial upload image auto submit" do
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

    sleep 1
    puts "DEBUG current_url=#{page.current_url}"
    puts "DEBUG page_text=#{page.text[0, 800]}"
    puts "DEBUG attached=#{CourseCategory.find_by(name: 'SystemTestKategorie')&.image&.attached?}"

    category = CourseCategory.find_by!(name: "SystemTestKategorie")
    assert category.image.attached?, "Bild muss nach dem Auswählen ohne separaten Klick automatisch hochgeladen werden"
  end
end
