class Holiday < ApplicationRecord
  validates :end_date, comparison: { greater_than_or_equal_to: :start_date }, allow_blank: true
end
