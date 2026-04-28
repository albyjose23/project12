require 'csv'
require 'rexml/document'
require 'zip'

class PagesController < ApplicationController
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
    @imported_questions = Question.imported_entries.includes(:subject).order(created_at: :desc)
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
    requested_total_marks = params[:total_marks].to_i
    generated_total_marks = calculate_total_marks(section_counts)
    shortages = unavailable_sections(@subject, section_counts)

    if section_counts.values.sum <= 0
      redirect_to pages_generate_paper_path, alert: "Enter at least one question count before generating the paper."
      return
    end

    if requested_total_marks <= 0
      redirect_to pages_generate_paper_path, alert: "Enter a valid total marks value."
      return
    end

    if generated_total_marks != requested_total_marks
      redirect_to pages_generate_paper_path, alert: "Total marks mismatch. The selected questions add up to #{generated_total_marks} marks."
      return
    end

    if shortages.any?
      redirect_to pages_generate_paper_path, alert: shortages.join(", ")
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
      questions_by_section = @subject.questions.to_a.group_by(&:section_name)
      ActiveRecord::Base.transaction do
        section_counts.each do |section, count|
          next if count <= 0

          questions_by_section.fetch(section, []).sample(count).each do |question|
            PaperQuestion.create!(paper: @paper, question: question)
          end
        end
      end

      redirect_to view_paper_path(id: @paper.id)
    else
      redirect_to pages_generate_paper_path, alert: "Failed to generate paper."
    end
  end

  def import_questions
    file = params[:file]
    subject = Subject.find(params[:subject_id])

    if file.present?
      begin
        import_rows(file).each do |row|
          create_imported_question!(row, subject)
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

  def generate_paper; end

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

  def unavailable_sections(subject, section_counts)
    available_counts = subject.questions.group(:marks).count

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

    extract_docx_paragraphs(file).each do |paragraph|
      original_line = paragraph.to_s.strip
      line = normalize_docx_line(original_line)
      next if line.blank?

      if (unit_match = docx_unit_heading_match(line))
        current_unit = unit_match[1].strip
        next
      end

      if (section_match = docx_section_heading_match(line))
        current_section = section_match[1].upcase
        next
      end

      content = normalize_docx_question(line)
      next if content.blank?

      if current_section.blank?
        raise ArgumentError, "Each Word question must come after a Section: A, B, or C line. Problem line: #{original_line.inspect}"
      end

      rows << {
        "content" => content,
        "section" => current_section,
        "unit" => current_unit
      }
    end

    raise ArgumentError, "No questions were found in the Word file." if rows.empty?

    rows
  end

  def docx_unit_heading_match(line)
    line.match(/\Aunit(?:\s*[:\-]\s*|\s+)(.+)\z/i)
  end

  def docx_section_heading_match(line)
    line.match(/\Asection(?:\s*[:\-]?\s*|\s+)([A-C])(?:\s*[:\-])?\z/i)
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
        paragraphs << text_parts.join
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
    line.gsub(/\A[\p{Space}\u2022\-\*\d\.\)\(]+\s*/u, "").strip
  end

  def create_imported_question!(row, subject)
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
      entry_mode: "imported"
    )
  end
end
