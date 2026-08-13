require "test_helper"

class NotificationPreviewBuilderTest < ActiveSupport::TestCase
  test "jede preview_method aus dem Katalog rendert ein Mail::Message mit Inhalt, ohne die DB zu berühren" do
    NotificationCatalog.all.select(&:preview_method).each do |entry|
      mail = NotificationPreviewBuilder.public_send(entry.preview_method)
      assert_not_nil mail, "#{entry.key}: preview lieferte nil (Mailer-Guard hat sie verschluckt?)"

      part = mail.html_part || mail
      assert part.body.decoded.present?, "#{entry.key}: gerenderter Body ist leer"
    end
  end

  test "Fake-Objekte werden nie gespeichert" do
    before_counts = %w[User Participant Course TrainingSession CourseRegistration Trainer].map { |k| [ k, k.constantize.count ] }.to_h

    NotificationCatalog.all.select(&:preview_method).each { |e| NotificationPreviewBuilder.public_send(e.preview_method) }

    after_counts = %w[User Participant Course TrainingSession CourseRegistration Trainer].map { |k| [ k, k.constantize.count ] }.to_h
    assert_equal before_counts, after_counts, "Preview darf keine Datensätze in der DB anlegen"
  end
end
