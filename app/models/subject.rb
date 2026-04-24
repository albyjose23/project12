class Subject < ApplicationRecord
  has_many :questions, dependent: :destroy
  has_many :papers
end