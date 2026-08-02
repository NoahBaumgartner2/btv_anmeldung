# Eine konkrete Jahres-Instanz eines HolidayType (z.B. "Herbstferien" ->
# 3.10.2026 - 18.10.2026). Der Name kommt vom zugehörigen Typ.
class Holiday < ApplicationRecord
  belongs_to :holiday_type

  validates :start_date, :end_date, presence: true
  validates :end_date, comparison: { greater_than_or_equal_to: :start_date }, allow_blank: true
end
