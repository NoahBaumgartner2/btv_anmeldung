# Kurskategorien (z.B. "Turnen", "Pilates") existieren primär als freier
# Textwert auf Course#category – dieses Model dient nur dazu, pro Kategorie-
# name ein Bild anzuhängen (für die spätere Startseiten-Darstellung). Wird
# per name (nicht Course-Assoziation) verknüpft, siehe
# CourseCategoriesController#index.
class CourseCategory < ApplicationRecord
  has_one_attached :image

  validates :name, presence: true, uniqueness: true

  def image_url
    return nil unless image.attached?

    Rails.application.routes.url_helpers.rails_storage_proxy_path(image, only_path: true)
  end
end
