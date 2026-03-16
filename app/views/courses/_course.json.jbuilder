json.extract! course, :id, :title, :description, :location, :start_date, :end_date, :allows_holiday_deduction, :registration_type, :has_ticketing, :has_payment, :created_at, :updated_at
json.url course_url(course, format: :json)
