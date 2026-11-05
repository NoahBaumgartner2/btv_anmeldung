require "test_helper"

class CoursePhotoTest < ActiveSupport::TestCase
  def png = { io: file_fixture("test_image.png").open, filename: "kurs.png", content_type: "image/png" }

  setup do
    @course = courses(:one)
    @course.update_columns(category: "Turnen")
  end

  test "card_image: eigenes Foto vor Kategorie-Bild, sonst nil" do
    assert_nil @course.card_image

    category = CourseCategory.create!(name: "Turnen")
    category.image.attach(png)
    assert_equal category.image.blob, @course.card_image.blob

    @course.photo.attach(png)
    assert_equal @course.photo.blob, @course.card_image.blob
  end

  test "lehnt Nicht-Bilder ab" do
    @course.photo = { io: StringIO.new("%PDF"), filename: "x.pdf", content_type: "application/pdf" }
    assert_not @course.valid?
    assert @course.errors[:photo].any?
  end

  test "remove_photo entfernt das Foto, ausser es kommt gleichzeitig ein neues" do
    @course.photo.attach(png)
    @course.update!(remove_photo: "1")
    assert_not @course.reload.photo.attached?

    @course.update!(photo: png, remove_photo: "1")
    assert @course.reload.photo.attached?
  end
end
