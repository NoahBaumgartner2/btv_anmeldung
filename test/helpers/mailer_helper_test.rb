require "test_helper"

class MailerHelperTest < ActionView::TestCase
  include MailerHelper

  setup do
    # Active-Storage-URL-Helper brauchen einen Host für rails_representation_url.
    Rails.application.routes.default_url_options[:host] = "example.com"
  end

  # Erzeugt eine ClubSetting mit echtem PNG-Logo der gewünschten Masse.
  def club_with_logo(width:, height:)
    club = ClubSetting.current
    club.save!
    png = Vips::Image.black(width, height).write_to_buffer(".png")
    club.logo.attach(io: StringIO.new(png), filename: "logo.png", content_type: "image/png")
    club
  end

  test "email_logo behält bei bekannten Massen das Seitenverhältnis" do
    club = club_with_logo(width: 100, height: 50)

    result = email_logo(club)

    assert_equal 56, result[:height]
    # 100 * 56 / 50 = 112, also Seitenverhältnis 2:1 erhalten (≤ 200 max-width)
    assert_equal 112, result[:width]
    assert_in_delta 100.0 / 50, result[:width].to_f / result[:height], 0.05
    assert result[:url].present?
  end

  test "email_logo setzt width nil bei unlesbaren Metadaten – keine Verzerrung" do
    # Inhalt, der nicht als Bild analysierbar ist → keine Breite/Höhe in den Metadaten.
    club = ClubSetting.current
    club.save!
    club.logo.attach(
      io: StringIO.new("nicht-wirklich-ein-bild"),
      filename: "logo.png",
      content_type: "image/png"
    )

    result = email_logo(club)

    assert_nil result[:width], "Ohne lesbare Masse darf keine fixe Breite (Verzerrung) gesetzt werden"
    assert_equal 56, result[:height]
    assert result[:url].present?
  end
end
