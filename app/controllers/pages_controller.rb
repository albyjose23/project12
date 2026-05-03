require 'csv'
require 'rexml/document'
require 'securerandom'
require 'zip'

class PagesController < ApplicationController
  UNIT_WORD_MAP = {
    "one" => "1",
    "two" => "2",
    "three" => "3",
    "four" => "4",
    "five" => "5"
  }.freeze

  before_action :authenticate_user!, except: [ :login, :register ]
  before_action :redirect_if_authenticated, only: [ :login, :register ]

  def login; end
  def register; end

  def dashboard
    @total_papers = Paper.count
    @total_questions = Question.count
    @total_subjects = Subject.count
    @recent_papers = Paper.includes(:subject).order(created_at: :desc).limit(5)
  end

  def question_bank
    @subjects = Subject.order(name: :asc)
    @typed_questions = Question.typed_entries.includes(:subject).order(created_at: :desc)
    @imported_batches = grouped_import_batches
  end

  def manage_subjects
    @subjects = Subject.all.order(code: :asc)
  end

  def add_subject
    @subject = Subject.new(name: params[:name], code: params[:code])
    if @subject.save
      redirect_to pages_manage_subjects_path, notice: "Subject created!"
    else
      redirect_to pages_manage_subjects_path, alert: "Failed to create subject."
    end
  end

  def add_question
    section = Question.resolve_section(marks: params[:marks], difficulty: params[:difficulty])
    attributes = Question.attributes_for_section(section)

    @question = Question.new(
      content: params[:content],
      difficulty: attributes[:difficulty] || params[:difficulty],
      marks: attributes[:marks] || params[:marks],
      subject_id: params[:subject_id],
      unit: params[:unit],
      entry_mode: "typed"
    )
    
    if @question.save
      redirect_to pages_question_bank_path, notice: "Question saved!"
    else
      redirect_to pages_question_bank_path, alert: "Error: #{@question.errors.full_messages.join(', ')}"
    end
  end

  def import_questions_page
    @subjects = Subject.order(name: :asc)
  end

  def delete_paper
    @paper = Paper.find(params[:id])
    @paper.destroy
    redirect_to pages_generated_papers_path, notice: "Paper deleted successfully."
  end

  def create_paper
    @subject = Subject.find(params[:subject_id])
    section_counts = requested_section_counts
    selected_units = requested_units
    available_questions = filtered_questions_for_paper(@subject, selected_units)
    requested_total_marks = params[:total_marks].to_i
    generated_total_marks = calculate_total_marks(section_counts)
    shortages = unavailable_sections(available_questions, section_counts)
    selected_questions = select_questions_for_paper(available_questions, section_counts)

    if section_counts.values.sum <= 0
      redirect_to_generate_paper(alert: "Enter at least one question count before generating the paper.", selected_units: selected_units)
      return
    end

    if unit_filter_requested? && selected_units.empty?
      redirect_to_generate_paper(alert: "Select at least one unit before generating the paper.", selected_units: selected_units)
      return
    end

    if requested_total_marks <= 0
      redirect_to_generate_paper(alert: "Enter a valid total marks value.", selected_units: selected_units)
      return
    end

    if generated_total_marks != requested_total_marks
      redirect_to_generate_paper(alert: "Total marks mismatch. The selected questions add up to #{generated_total_marks} marks.", selected_units: selected_units)
      return
    end

    if shortages.any?
      redirect_to_generate_paper(alert: shortages.join(", "), selected_units: selected_units)
      return
    end

    if selected_questions.values.flatten.size != section_counts.values.sum
      redirect_to_generate_paper(alert: "Unable to build a paper from the available question bank for the selected units.", selected_units: selected_units)
      return
    end

    @paper = Paper.new(
      title: params[:title],
      exam_type: params[:exam_type],
      subject: @subject,
      total_marks: requested_total_marks,
      duration: params[:duration],
      instructions: params[:instructions]
    )

    if @paper.save
      ActiveRecord::Base.transaction do
        selected_questions.each_value do |questions|
          questions.each do |question|
            PaperQuestion.create!(paper: @paper, question: question)
          end
        end
      end

      redirect_to view_paper_path(id: @paper.id)
    else
      redirect_to_generate_paper(alert: "Failed to generate paper.", selected_units: selected_units)
    end
  end

  def import_questions
    file = params[:file]
    subject = Subject.find(params[:subject_id])

    if file.present?
      begin
        import_batch_id = SecureRandom.uuid
        import_source_name = file.original_filename.to_s

        ActiveRecord::Base.transaction do
          import_rows(file).each do |row|
            create_imported_question!(
              row,
              subject,
              import_batch_id: import_batch_id,
              import_source_name: import_source_name
            )
          end
        end

        redirect_to pages_question_bank_path, notice: "Questions imported successfully!"
      rescue CSV::MalformedCSVError, ArgumentError, ActiveRecord::RecordInvalid => e
        redirect_to pages_question_bank_path, alert: "Import error: #{e.message}"
      end
    else
      redirect_to pages_question_bank_path, alert: "Please upload a valid CSV or DOCX file."
    end
  end

  def edit_subject
    @subject = Subject.find(params[:id])
  end

  def update_subject
    @subject = Subject.find(params[:id])
    if @subject.update(name: params[:name], code: params[:code])
      redirect_to pages_manage_subjects_path, notice: "Subject updated successfully!"
    else
      render :edit_subject, alert: "Failed to update subject."
    end
  end

  def edit_question
    @question = Question.find(params[:id])
    @subjects = Subject.order(name: :asc)
  end

  def update_question
    @question = Question.find(params[:id])
    section = Question.resolve_section(marks: params[:marks], difficulty: params[:difficulty])
    attributes = Question.attributes_for_section(section)

    if @question.update(
      content: params[:content],
      marks: attributes[:marks] || params[:marks],
      difficulty: attributes[:difficulty] || params[:difficulty],
      unit: params[:unit],
      subject_id: params[:subject_id]
    )
      redirect_to pages_question_bank_path, notice: "Question updated successfully!"
    else
      redirect_to edit_question_path(@question), alert: "Failed to update question."
    end
  end

  def delete_question
    @question = Question.find(params[:id])
    @question.destroy
    redirect_to pages_question_bank_path, notice: "Question deleted successfully."
  end

  def delete_import_batch
    batch_questions = imported_questions_for_group(params[:group_key] || params[:batch_id])

    if batch_questions.exists?
      file_name = batch_questions.first.import_source_label
      batch_questions.destroy_all
      redirect_to pages_question_bank_path, notice: "#{file_name} deleted successfully."
    else
      redirect_to pages_question_bank_path, alert: "Imported file not found."
    end
  end

  def generate_paper
    @selected_units = flash.key?(:selected_units) ? Array(flash[:selected_units]).map(&:to_s) : available_unit_options
  end

  def generated_papers
    @papers = Paper.includes(:subject).order(created_at: :desc)
  end

  def view_paper
    @paper = Paper.find(params[:id])
    questions = @paper.questions.to_a
    @section_a_questions = questions.select { |question| question.section_name == "A" }
    @section_b_questions = questions.select { |question| question.section_name == "B" }
    @section_c_questions = questions.select { |question| question.section_name == "C" }
  end

  private

  def redirect_if_authenticated
    redirect_to pages_dashboard_path if user_signed_in?
  end

  def requested_section_counts
    {
      "A" => params[:section_a_count].to_i,
      "B" => params[:section_b_count].to_i,
      "C" => params[:section_c_count].to_i
    }
  end

  def calculate_total_marks(section_counts)
    section_counts.sum do |section, count|
      count * Question::SECTION_RULES.fetch(section)[:marks]
    end
  end

  def unavailable_sections(questions, section_counts)
    available_counts = questions.group_by(&:marks).transform_values(&:count)

    section_counts.filter_map do |section, count|
      next if count <= 0

      marks = Question::SECTION_RULES.fetch(section)[:marks]
      available = available_counts.fetch(marks, 0)
      next if available >= count

      "Only #{available} question(s) available for #{marks}-mark section"
    end
  end

  def load_csv_content(file)
    raw_content = file.read
    raw_content.force_encoding(Encoding::BINARY)

    [ "utf-8", "windows-1252", "iso-8859-1" ].each do |encoding|
      converted = raw_content.encode(
        Encoding::UTF_8,
        encoding,
        invalid: :replace,
        undef: :replace,
        replace: ""
      )
      return converted if converted.valid_encoding?
    rescue Encoding::UndefinedConversionError, Encoding::InvalidByteSequenceError
      next
    end

    raw_content.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
  end

  def import_rows(file)
    case File.extname(file.original_filename.to_s).downcase
    when ".csv"
      parse_csv_rows(file)
    when ".docx"
      parse_docx_rows(file)
    else
      raise ArgumentError, "Only CSV and DOCX files are supported."
    end
  end

  def parse_csv_rows(file)
    csv_content = load_csv_content(file)

    CSV.parse(csv_content, headers: true).map(&:to_h)
  end

  def parse_docx_rows(file)
    rows = []
    current_unit = nil
    current_section = nil
    current_question_lines = []

    extract_docx_paragraphs(file).each do |paragraph|
      original_line = paragraph.fetch(:text).to_s.strip
      line = normalize_docx_line(original_line)
      next if line.blank?

      if (unit_match = docx_unit_heading_match(line))
        append_docx_question!(rows, current_question_lines, current_section, current_unit)
        current_question_lines = []
        current_unit = unit_match[1].strip
        current_section = nil
        next
      end

      if (section_match = docx_section_heading_match(line))
        append_docx_question!(rows, current_question_lines, current_section, current_unit)
        current_question_lines = []
        current_section = section_match[1].upcase
        next
      end

      next if current_unit.blank? || current_section.blank?

      if docx_question_continuation?(line, paragraph, current_question_lines)
        current_question_lines << line
        next
      end

      append_docx_question!(rows, current_question_lines, current_section, current_unit)
      current_question_lines = [ line ]
    end

    append_docx_question!(rows, current_question_lines, current_section, current_unit)
    raise ArgumentError, "No questions were found in the Word file." if rows.empty?

    rows
  end

  def docx_unit_heading_match(line)
    line.match(/\Aunit(?:\s*[:\-]\s*|\s+)(.+)\z/i)
  end

  def docx_section_heading_match(line)
    line.match(/\Asection\s*[:\-]?\s*([A-C])(?:\s*[-:]\s*(?:\d+\s*marks?)?)?\z/i)
  end

  def extract_docx_paragraphs(file)
    paragraphs = []

    Zip::File.open_buffer(File.binread(file.tempfile.path)) do |zip_file|
      document_entry = zip_file.find_entry("word/document.xml")
      raise ArgumentError, "The DOCX file is missing document content." unless document_entry

      xml = REXML::Document.new(document_entry.get_input_stream.read)
      REXML::XPath.each(xml, "//w:body/w:p", { "w" => "http://schemas.openxmlformats.org/wordprocessingml/2006/main" }) do |paragraph|
        text_parts = []
        REXML::XPath.each(paragraph, ".//w:t", { "w" => "http://schemas.openxmlformats.org/wordprocessingml/2006/main" }) do |node|
          text_parts << node.text.to_s
        end
        paragraphs << {
          text: text_parts.join,
          list_item: REXML::XPath.first(paragraph, ".//w:numPr", { "w" => "http://schemas.openxmlformats.org/wordprocessingml/2006/main" }).present?
        }
      end
    end

    paragraphs
  end

  def normalize_docx_line(line)
    line.to_s
      .unicode_normalize(:nfkc)
      .tr("\u00A0\u2007\u202F", "   ")
      .delete("\u200B\u200C\u200D\u2060\uFEFF")
      .tr("\u2013\u2014\u2212", "---")
      .gsub(/[[:space:]]+/, " ")
      .strip
  end

  def normalize_docx_question(line)
    line
      .gsub(/\A\d+\s*[\.\)]\s*[A-Za-z][\.\)]\s*/u, "")
      .gsub(/\A\d+\s*[\.\)]\s*/u, "")
      .gsub(/\A[\p{Space}\u2022\-\*\(\)]+\s*/u, "")
      .strip
  end

  def docx_question_continuation?(line, paragraph, current_question_lines)
    return false if current_question_lines.blank?

    paragraph[:list_item] || current_question_lines.last.to_s.end_with?(":") || current_question_lines.first.to_s.end_with?(":")
  end

  def append_docx_question!(rows, question_lines, current_section, current_unit)
    return if question_lines.blank? || current_section.blank?

    content = question_lines.map { |line| normalize_docx_question(line) }.reject(&:blank?).join(" ").strip
    return if content.blank?

    rows << {
      "content" => content,
      "section" => current_section,
      "unit" => current_unit
    }
  end

  def select_questions_for_paper(questions, section_counts)
    questions_by_section = questions.group_by(&:section_name)

    section_counts.each_with_object({}) do |(section, count), selected|
      selected[section] = balanced_section_questions(questions_by_section.fetch(section, []), count)
    end
  end

  def balanced_section_questions(questions, count)
    return [] if count <= 0

    buckets = questions.group_by { |question| normalized_unit_value(question.unit) || question.unit.to_s.strip.presence || "General" }
      .transform_values { |entries| entries.shuffle }
    unit_order = buckets.keys.sort_by { |unit| unit_sort_key(unit) }.shuffle
    selected = []

    while selected.size < count
      picked_in_round = false

      unit_order.each do |unit|
        next if buckets[unit].blank?

        selected << buckets[unit].shift
        picked_in_round = true
        break if selected.size >= count
      end

      break unless picked_in_round
    end

    selected
  end

  def unit_sort_key(unit)
    match = unit.to_s.match(/\d+/)
    [ match ? 0 : 1, match ? match[0].to_i : unit.to_s.downcase ]
  end

  def requested_units
    Array(params[:units])
      .map { |value| normalized_unit_value(value) }
      .select { |unit| available_unit_options.include?(unit) }
      .uniq
  end

  def unit_filter_requested?
    params[:unit_filter_present].present? || params.key?(:units)
  end

  def available_unit_options
    %w[1 2 3 4 5]
  end

  def filtered_questions_for_paper(subject, selected_units)
    questions = subject.questions.to_a
    return questions if selected_units.empty?

    questions.select do |question|
      selected_units.include?(normalized_unit_value(question.unit))
    end
  end

  def normalized_unit_value(unit)
    text = unit.to_s.strip
    return if text.blank?

    digit_match = text.match(/\b([1-5])\b/)
    return digit_match[1] if digit_match

    UNIT_WORD_MAP.each do |word, number|
      return number if text.downcase.include?(word)
    end

    nil
  end

  def redirect_to_generate_paper(alert:, selected_units:)
    flash[:selected_units] = selected_units
    redirect_to pages_generate_paper_path, alert: alert
  end

  def grouped_import_batches
    Question.imported_entries
      .includes(:subject)
      .order(created_at: :desc)
      .group_by { |question| import_group_key_for(question) }
      .map do |group_key, questions|
        first_question = questions.first

        {
          group_key: group_key,
          file_name: import_group_label_for(first_question),
          question_count: questions.size,
          subject_codes: questions.map { |question| question.subject.code }.uniq.sort,
          imported_at: questions.max_by(&:created_at)&.created_at
        }
      end
      .sort_by { |batch| batch[:imported_at] || Time.at(0) }
      .reverse
  end

  def create_imported_question!(row, subject, import_batch_id:, import_source_name:)
    section_attributes = Question.attributes_for_section(row["section"])
    section = Question.resolve_section(
      section: row["section"],
      marks: row["marks"],
      difficulty: row["difficulty"]
    )
    resolved_attributes = Question.attributes_for_section(section)

    Question.create!(
      content: row["content"],
      difficulty: resolved_attributes[:difficulty] || section_attributes[:difficulty] || row["difficulty"],
      marks: resolved_attributes[:marks] || section_attributes[:marks] || row["marks"],
      unit: row["unit"],
      subject: subject,
      entry_mode: "imported",
      import_batch_id: import_batch_id,
      import_source_name: import_source_name
    )
  end

  def import_group_key_for(question)
    if question.import_batch_id.present?
      "batch:#{question.import_batch_id}"
    elsif question.import_source_name.present?
      "source:#{question.import_source_name}"
    else
      "legacy:#{question.id}"
    end
  end

  def import_group_label_for(question)
    question.import_source_label
  end

  def imported_questions_for_group(group_key)
    return Question.none if group_key.blank?

    if group_key.start_with?("batch:")
      Question.for_import_batch(group_key.delete_prefix("batch:"))
    elsif group_key.start_with?("source:")
      Question.imported_entries.where(import_batch_id: nil, import_source_name: group_key.delete_prefix("source:"))
    elsif group_key.start_with?("legacy:")
      Question.imported_entries.where(id: group_key.delete_prefix("legacy:"))
    else
      Question.none
    end
  end
end
