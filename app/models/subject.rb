class Subject < ApplicationRecord
  belongs_to :user
  has_many :questions, dependent: :destroy
  has_many :papers, dependent: :destroy

  validates :name, :code, presence: true
end
