class Paper < ApplicationRecord
  belongs_to :subject
  belongs_to :user, inverse_of: :exam_papers
  has_many :paper_questions, dependent: :destroy
  has_many :questions, through: :paper_questions

  before_validation :assign_user_from_subject

  validate :subject_owner_matches_user

  private

  def assign_user_from_subject
    self.user ||= subject&.user
  end

  def subject_owner_matches_user
    return if subject.blank? || user.blank? || subject.user_id == user_id

    errors.add(:subject, "must belong to the same user")
  end
end
