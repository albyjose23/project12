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
  has_many :paper_questions, dependent: :destroy
  has_many :papers, through: :paper_questions

  scope :typed_entries, -> { where(entry_mode: "typed") }
  scope :imported_entries, -> { where(entry_mode: "imported") }

  before_validation :normalize_section_fields
  before_validation :normalize_entry_mode

  validates :content, :difficulty, :marks, :entry_mode, presence: true
  validates :entry_mode, inclusion: { in: ENTRY_MODES.keys }

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

  def self.attributes_for_section(section)
    normalized_section = resolve_section(section: section)
    normalized_section ? SECTION_RULES.fetch(normalized_section).dup : {}
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

  def self.integer_or_nil(value)
    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end
end
