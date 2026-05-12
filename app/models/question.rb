class Question < ApplicationRecord
  ENTRY_MODES = {
    "typed" => "Typed",
    "imported" => "Imported"
  }.freeze

  SECTION_RULES = {
    "A" => { marks: 2, difficulty: "Easy" },
    "B" => { marks: 6, difficulty: "Medium" },
    "C" => { marks: 8, difficulty: "Hard" }
  }.freeze

  belongs_to :subject
  belongs_to :user, inverse_of: :question_banks
  has_many :paper_questions, dependent: :destroy
  has_many :papers, through: :paper_questions

  scope :typed_entries, -> { where(entry_mode: "typed") }
  scope :imported_entries, -> { where(entry_mode: "imported") }
  scope :for_import_batch, ->(batch_id) { imported_entries.where(import_batch_id: batch_id) }

  before_validation :normalize_section_fields
  before_validation :normalize_entry_mode
  before_validation :assign_user_from_subject

  validates :content, :difficulty, :marks, :entry_mode, presence: true
  validates :entry_mode, inclusion: { in: ENTRY_MODES.keys }
  validate :subject_owner_matches_user

  def self.section_options
    SECTION_RULES.map do |section, attributes|
      [ section, "#{attributes[:marks]} Marks", attributes ]
    end
  end

  def section_name
    self.class.resolve_section(marks: marks, difficulty: difficulty) || "General"
  end

  def display_marks
    SECTION_RULES.fetch(section_name, {})[:marks] || marks
  end

  def entry_mode_label
    ENTRY_MODES.fetch(entry_mode, entry_mode.to_s.humanize)
  end

  def import_source_label
    import_source_name.presence || "Imported File"
  end

  def self.attributes_for_section(section)
    normalized_section = resolve_section(section: section)
    normalized_section ? SECTION_RULES.fetch(normalized_section).dup : {}
  end

  def self.normalize_unit_value(unit)
    text = unit.to_s.strip
    return if text.blank?

    digit_match = text.match(/\b(\d+)\b/)
    return digit_match[1] if digit_match

    compact_text = text.downcase.gsub(/[^a-z]/, "")

    {
      "one" => "1",
      "two" => "2",
      "three" => "3",
      "four" => "4",
      "five" => "5",
      "six" => "6",
      "seven" => "7",
      "eight" => "8",
      "nine" => "9",
      "ten" => "10",
      "i" => "1",
      "ii" => "2",
      "iii" => "3",
      "iv" => "4",
      "v" => "5",
      "vi" => "6",
      "vii" => "7",
      "viii" => "8",
      "ix" => "9",
      "x" => "10"
    }[compact_text]
  end

  def self.resolve_section(section: nil, marks: nil, difficulty: nil)
    normalized_section = section.to_s.strip.upcase
    return normalized_section if SECTION_RULES.key?(normalized_section)

    marks_value = integer_or_nil(marks)
    return "A" if marks_value == 2
    return "B" if marks_value == 6
    return "C" if marks_value == 8

    case difficulty.to_s.strip.downcase
    when "easy"
      "A"
    when "medium"
      "B"
    when "hard"
      "C"
    end
  end

  private

  def normalize_section_fields
    normalized_section = self.class.resolve_section(marks: marks, difficulty: difficulty)
    return unless normalized_section

    rule = SECTION_RULES.fetch(normalized_section)
    self.marks = rule[:marks]
    self.difficulty = rule[:difficulty]
  end

  def normalize_entry_mode
    normalized_mode = entry_mode.to_s.strip.downcase
    self.entry_mode = ENTRY_MODES.key?(normalized_mode) ? normalized_mode : "typed"
  end

  def assign_user_from_subject
    self.user ||= subject&.user
  end

  def subject_owner_matches_user
    return if subject.blank? || user.blank? || subject.user_id == user_id

    errors.add(:subject, "must belong to the same user")
  end

  def self.integer_or_nil(value)
    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end
end
