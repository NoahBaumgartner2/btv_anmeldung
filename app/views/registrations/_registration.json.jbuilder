json.extract! registration, :id, :first_name, :last_name, :email, :phone_number, :ahv_number, :date_of_birth, :gender, :created_at, :updated_at
json.url registration_url(registration, format: :json)
