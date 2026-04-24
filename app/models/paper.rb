class Paper < ApplicationRecord
  belongs_to :subject
  has_many :paper_questions, dependent: :destroy
  has_many :questions, through: :paper_questions
end