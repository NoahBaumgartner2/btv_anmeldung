json.extract! training_session, :id, :course_id, :start_time, :end_time, :is_canceled, :created_at, :updated_at
json.url training_session_url(training_session, format: :json)
