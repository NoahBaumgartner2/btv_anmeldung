# Kurskategorien (z.B. "Turnen", "Pilates") existieren primär als freier
# Textwert auf Course#category – dieses Model dient nur dazu, pro Kategorie-
# name ein Bild anzuhängen (für die spätere Startseiten-Darstellung). Wird
# per name (nicht Course-Assoziation) verknüpft, siehe
# CourseCategoriesController#index.
class CourseCategory < ApplicationRecord
  has_one_attached :image

  validates :name, presence: true, uniqueness: true
end
