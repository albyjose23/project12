class Question < ApplicationRecord
  belongs_to :subject
  has_many :paper_questions
  has_many :papers, through: :paper_questions
end