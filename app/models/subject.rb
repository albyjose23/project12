class Subject < ApplicationRecord
  has_many :questions, dependent: :destroy #
  has_many :papers #
  
  validates :name, :code, presence: true
end