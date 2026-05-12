require "digest"
require "securerandom"
require "uri"

class User < ApplicationRecord
  EMAIL_FORMAT = URI::MailTo::EMAIL_REGEXP
  MINIMUM_PASSWORD_LENGTH = 8
  PASSWORD_RESET_TOKEN_TTL = 30.minutes

  normalizes :email, with: ->(email) { email.strip.downcase }

  has_secure_password

  has_many :subjects, dependent: :destroy
  has_many :question_banks, class_name: "Question", dependent: :destroy, inverse_of: :user
  has_many :questions, class_name: "Question", inverse_of: :user
  has_many :exam_papers, class_name: "Paper", dependent: :destroy, inverse_of: :user
  has_many :papers, class_name: "Paper", inverse_of: :user

  validates :name, presence: true
  validates :email, presence: true, format: { with: EMAIL_FORMAT }, uniqueness: { case_sensitive: false }
  validates :department, presence: true
  validates :role, presence: true
  validates :password, length: { minimum: MINIMUM_PASSWORD_LENGTH }, allow_nil: true

  def self.find_by_email_for_authentication(email)
    normalized_email = email.to_s.strip.downcase
    return if normalized_email.blank?

    find_by("lower(email) = ?", normalized_email)
  end

  def generate_password_reset_token!
    token = SecureRandom.urlsafe_base64(32)

    update!(
      reset_password_token: self.class.digest_password_reset_token(token),
      reset_password_sent_at: Time.current
    )

    token
  end

  def password_reset_token_valid?(token)
    return false if token.blank? || reset_password_token.blank? || password_reset_expired?

    ActiveSupport::SecurityUtils.secure_compare(
      reset_password_token,
      self.class.digest_password_reset_token(token)
    )
  end

  def password_reset_expired?
    reset_password_sent_at.blank? || reset_password_sent_at <= PASSWORD_RESET_TOKEN_TTL.ago
  end

  def clear_password_reset_token!
    update!(
      reset_password_token: nil,
      reset_password_sent_at: nil
    )
  end

  def self.find_by_password_reset_token(token)
    return if token.blank?

    user = find_by(reset_password_token: digest_password_reset_token(token))
    user if user&.password_reset_token_valid?(token)
  end

  def self.digest_password_reset_token(token)
    Digest::SHA256.hexdigest(token.to_s)
  end
end
