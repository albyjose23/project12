class User < ApplicationRecord
  normalizes :email, with: ->(email) { email.strip.downcase }

  has_secure_password

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true
  validates :department, presence: true
  validates :role, presence: true
end
