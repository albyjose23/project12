class QuestionBankParser
  VALID_SECTIONS = %w[A B C].freeze
  VALID_UNITS = %w[1 2 3 4 5].freeze
  QUESTION_NUMBER_PATTERN = /(?:\A|(?<=\s))(\d{1,2})\s*(?:[\.\)])?\s*(?=[A-Za-z\(])/i
  UNIT_HEADING_PATTERN = /\bunit\b\s*[-:.–]?\s*([a-z0-9]+(?:\.[a-z0-9]+)?)/i
  SECTION_HEADING_PATTERN = /\bsection\b\s*[-:–]?\s*([abc])\b/i
  SECTION_HEADING_PREFIX_PATTERN = /\A\s*section\b\s*[-:–]?\s*[abc]\b/i

  def self.parse(paragraphs)
    new(paragraphs).parse
  end

  def initialize(paragraphs)
    @paragraphs = Array(paragraphs)
    @questions = []
    @current_unit = nil
    @current_section = nil
    @current_question_number = nil
    @current_question_parts = []
    @pending_question_prefix_parts = []
    @last_question_number_by_section = Hash.new(0)
  end

  def parse
    @paragraphs.each do |paragraph|
      paragraph = normalize(paragraph)
      next if paragraph.empty?

      process_paragraph(paragraph)
    end

    infer_pending_question!
    flush_question!
    @questions
  end

  private

  def normalize(text)
    text.to_s
      .tr("\u00A0", " ")
      .encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
      .gsub(/[[:space:]]+/, " ")
      .strip
  end

  def detect_unit(text)
    match = text.match(UNIT_HEADING_PATTERN)
    return unless match

    normalized_unit = Question.normalize_unit_value(match[1])
    return unless VALID_UNITS.include?(normalized_unit)

    "Unit #{normalized_unit}"
  end

  def detect_section(text)
    match = text.match(SECTION_HEADING_PATTERN)
    section = match && match[1].upcase
    VALID_SECTIONS.include?(section) ? section : nil
  end

  def process_paragraph(paragraph)
    remaining = paragraph

    loop do
      heading_type, heading_match = next_heading_match(remaining)

      unless heading_match
        process_question_text(remaining)
        break
      end

      if heading_match.begin(0).positive?
        process_question_text(remaining[0...heading_match.begin(0)])
        remaining = remaining[heading_match.begin(0)..]
        next
      end

      case heading_type
      when :unit
        process_unit_heading!(remaining)
        next_section_match = SECTION_HEADING_PATTERN.match(remaining, heading_match.end(0))
        break unless next_section_match

        remaining = remaining[next_section_match.begin(0)..]
      when :section
        process_section_heading!(remaining)
        remaining = strip_section_heading_prefix(remaining)
        break if remaining.empty?
      end
    end
  end

  def next_heading_match(text)
    unit_match = UNIT_HEADING_PATTERN.match(text)
    section_match = SECTION_HEADING_PATTERN.match(text)

    if unit_match && (!section_match || unit_match.begin(0) <= section_match.begin(0))
      [ :unit, unit_match ]
    elsif section_match
      [ :section, section_match ]
    else
      [ nil, nil ]
    end
  end

  def process_unit_heading!(text)
    unit = detect_unit(text)
    return unless unit

    infer_pending_question!
    flush_question!
    reset_section_state!
    @current_unit = unit
  end

  def process_section_heading!(text)
    section = detect_section(text)
    return unless section

    infer_pending_question!
    flush_question!
    @current_section = section
    reset_question_buffer!
  end

  def process_question_text(text)
    text = normalize_fragment(text)
    return if text.empty? || ignore?(text)
    return unless @current_unit && @current_section

    parse_question_paragraph(text)
  end

  def strip_section_heading_prefix(text)
    text
      .sub(SECTION_HEADING_PREFIX_PATTERN, "")
      .sub(/\A\s*[^A-Za-z0-9]+/, "")
      .sub(/\A\s*\(?\d+\s*marks?\)?/i, "")
      .sub(/\A\s*[^A-Za-z0-9]+/, "")
      .strip
  end

  def parse_question_paragraph(paragraph)
    candidates = question_number_candidates(paragraph)

    if candidates.empty?
      append_non_numbered_text(paragraph)
      return
    end

    valid_candidates = accepted_candidates(candidates)
    if valid_candidates.empty?
      append_non_numbered_text(paragraph)
      return
    end

    first_candidate = valid_candidates.first
    leading_text = normalize_fragment(paragraph[0...first_candidate[:start_index]])
    append_leading_text(leading_text) if leading_text.present?

    valid_candidates.each_with_index do |candidate, index|
      next_start = valid_candidates[index + 1]&.fetch(:start_index, nil) || paragraph.length
      question_text = normalize_fragment(paragraph[candidate[:text_start_index]...next_start])
      next if question_text.blank?

      start_new_question(candidate[:number], question_text)
    end
  end

  def question_number_candidates(paragraph)
    candidates = []

    paragraph.to_enum(:scan, QUESTION_NUMBER_PATTERN).each do
      match = Regexp.last_match
      candidates << {
        number: match[1].to_i,
        start_index: match.begin(1),
        text_start_index: match.end(0),
        at_start: match.begin(1).zero?
      }
    end

    candidates
  end

  def accepted_candidates(candidates)
    accepted = []
    expected_next_number = if @current_question_number
      @current_question_number + 1
    else
      @last_question_number_by_section[@current_section] + 1
    end

    candidates.each do |candidate|
      if accepted.empty?
        next unless valid_first_candidate?(candidate, expected_next_number)
      else
        next unless candidate[:number] == accepted.last[:number] + 1
      end

      accepted << candidate
    end

    accepted
  end

  def valid_first_candidate?(candidate, expected_next_number)
    return true if candidate[:number] == expected_next_number
    return false unless candidate[:number] == 1

    candidate[:at_start] || @pending_question_prefix_parts.any?
  end

  def append_leading_text(text)
    if @current_question_number
      @current_question_parts << text
    else
      @pending_question_prefix_parts << text
    end
  end

  def append_non_numbered_text(text)
    if @current_question_number
      @current_question_parts << text
    else
      infer_pending_question! if @pending_question_prefix_parts.any?
      @pending_question_prefix_parts << text
    end
  end

  def start_new_question(number, text)
    flush_question!
    @current_question_number = number
    @current_question_parts = []

    if @pending_question_prefix_parts.any?
      @current_question_parts.concat(@pending_question_prefix_parts)
      @pending_question_prefix_parts = []
    end

    @current_question_parts << text
  end

  def flush_question!
    return unless @current_unit && @current_section && @current_question_number

    text = normalize_fragment(@current_question_parts.join(" "))
    question_number = @current_question_number
    reset_question_buffer!
    return if text.blank?

    @last_question_number_by_section[@current_section] = question_number
    @questions << {
      "unit" => @current_unit,
      "section" => @current_section,
      "question_no" => question_number,
      "text" => text
    }
  end

  def infer_pending_question!
    return unless @current_unit && @current_section
    return if @current_question_number || @pending_question_prefix_parts.empty?

    inferred_text = normalize_fragment(@pending_question_prefix_parts.join(" "))
    @pending_question_prefix_parts = []
    return if inferred_text.blank?

    inferred_number = @last_question_number_by_section[@current_section] + 1
    @last_question_number_by_section[@current_section] = inferred_number
    @questions << {
      "unit" => @current_unit,
      "section" => @current_section,
      "question_no" => inferred_number,
      "text" => inferred_text
    }
  end

  def normalize_fragment(text)
    text.to_s.gsub(/[[:space:]]+/, " ").strip
  end

  def reset_section_state!
    @current_section = nil
    reset_question_buffer!
    @last_question_number_by_section.clear
  end

  def reset_question_buffer!
    @current_question_number = nil
    @current_question_parts = []
    @pending_question_prefix_parts = []
  end

  def ignore?(text)
    text.match?(/\A((\d+\s+)?marks?|answer all|answer any|each question carries|time)\b/i)
  end
end
