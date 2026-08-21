require "test_helper"

class CourseCategoriesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @admin = users(:admin)
    @course = Course.new(title: "Bild-Test", category: "Bildkategorie",
      registration_type: "semester", registration_mode: "semester",
      has_payment: false, has_ticketing: false, allows_holiday_deduction: false)
    @course.save!(validate: false)
  end

  test "index legt für jede Kategorie einen CourseCategory-Datensatz an" do
    sign_in @admin

    assert_not CourseCategory.exists?(name: "Bildkategorie")
    get course_categories_path

    assert_response :success
    assert CourseCategory.exists?(name: "Bildkategorie")
  end

  test "update_image hängt ein Bild an die Kategorie an" do
    sign_in @admin
    category = CourseCategory.create!(name: "Bildkategorie")
    image = fixture_file_upload("test_image.png", "image/png")

    patch update_image_course_category_path(category), params: { course_category: { image: image } }

    assert_redirected_to course_categories_path
    assert category.reload.image.attached?
  end

  test "destroy_image entfernt das Bild" do
    sign_in @admin
    category = CourseCategory.create!(name: "Bildkategorie")
    category.image.attach(io: File.open(file_fixture("test_image.png")), filename: "test_image.png", content_type: "image/png")

    delete destroy_image_course_category_path(category)

    assert_redirected_to course_categories_path
    assert_not category.reload.image.attached?
  end

  test "nicht-admin kommt nicht auf die Kategorien-Seite" do
    sign_in users(:one)

    get course_categories_path

    assert_redirected_to root_path
  end
end
