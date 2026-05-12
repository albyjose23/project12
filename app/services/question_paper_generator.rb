class QuestionPaperGenerator
  VALID_SECTIONS = %w[A B C].freeze
  VALID_UNITS = %w[1 2 3 4 5].freeze

  def initialize(questions:, selected_units: [])
    @questions = Array(questions)
    @selected_units = Array(selected_units).map(&:to_s) & VALID_UNITS
  end

  def questions_for_section(section, count)
    normalized_section = section.to_s.upcase
    return [] if count.to_i <= 0
    return [] unless VALID_SECTIONS.include?(normalized_section)

    filtered_questions
      .select { |question| question.section_name == normalized_section }
      .shuffle
      .first(count.to_i)
  end

  def build(section_counts)
    section_counts.each_with_object({}) do |(section, count), selected|
      selected[section] = questions_for_section(section, count)
    end
  end

  def questions_for_unit_and_section(unit, section, count)
    normalized_section = section.to_s.upcase
    normalized_unit = unit.to_s
    return [] if count.to_i <= 0
    return [] unless VALID_SECTIONS.include?(normalized_section)
    return [] unless VALID_UNITS.include?(normalized_unit)

    @questions
      .select do |question|
        Question.normalize_unit_value(question.unit) == normalized_unit &&
          question.section_name == normalized_section
      end
      .shuffle
      .first(count.to_i)
  end

  def build_manual(manual_section_counts)
    manual_section_counts.each_with_object({}) do |(unit, section_counts), selected|
      section_counts.each do |section, count|
        selected["#{unit}_#{section}"] = questions_for_unit_and_section(unit, section, count)
      end
    end
  end

  private

  def filtered_questions
    return @questions if @selected_units.empty?

    @questions.select do |question|
      normalized_unit = Question.normalize_unit_value(question.unit)
      normalized_unit.present? && @selected_units.include?(normalized_unit)
    end
  end
end
