class TrainingSession < ApplicationRecord
  belongs_to :course

  has_many :attendances, dependent: :destroy
end
