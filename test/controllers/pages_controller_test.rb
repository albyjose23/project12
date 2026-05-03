require "test_helper"
require "cgi"
require "rack/test"
require "zip"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test Faculty",
      email: "faculty@example.com",
      department: "BCA",
      role: "Professor",
      password: "Password123",
      password_confirmation: "Password123"
    )
  end

  test "should get register" do
    get pages_register_url
    assert_response :success
  end

  test "should get login" do
    get pages_login_url
    assert_response :success
  end

  test "should register a user" do
    post pages_register_url, params: {
      user: {
        name: "New Faculty",
        email: "new@example.com",
        department: "BCA",
        role: "Professor",
        password: "Password123",
        password_confirmation: "Password123"
      }
    }

    assert_redirected_to pages_dashboard_url
  end

  test "should allow registered user to log in" do
    post pages_login_url, params: {
      session: {
        email: @user.email,
        password: "Password123"
      }
    }

    assert_redirected_to pages_dashboard_url
  end

  test "should reject invalid login" do
    post pages_login_url, params: {
      session: {
        email: @user.email,
        password: "wrong-password"
      }
    }

    assert_response :unprocessable_entity
  end

  test "should redirect unauthenticated dashboard access" do
    get pages_dashboard_url
    assert_redirected_to pages_login_url
  end

  test "should get dashboard when logged in" do
    sign_in
    get pages_dashboard_url
    assert_response :success
  end

  test "should get manage_subjects when logged in" do
    sign_in
    get pages_manage_subjects_url
    assert_response :success
  end

  test "should get question_bank when logged in" do
    sign_in
    get pages_question_bank_url
    assert_response :success
  end

  test "should get generate_paper when logged in" do
    sign_in
    get pages_generate_paper_url
    assert_response :success
    assert_match 'name="units[]"', response.body
    assert_match "Unit 5", response.body
  end

  test "should get generated_papers when logged in" do
    sign_in
    get pages_generated_papers_url
    assert_response :success
  end

  test "should get view_paper when logged in" do
    sign_in
    paper = Paper.create!(title: "Sample Paper", subject: Subject.create!(name: "Data Structures", code: "CS101", department: "BCA", semester: "Semester 1"))
    get view_paper_url(id: paper.id)
    assert_response :success
  end

  test "view_paper uses exam paper print format with section numbering reset" do
    sign_in
    subject = Subject.create!(name: "PHP & MYSQL", code: "BCA301", department: "BCA", semester: "Semester 3")
    paper = Paper.create!(
      title: "III BCA MODEL EXAMINATION - JUNE 2024",
      subject: subject,
      duration: "2.5 Hrs",
      total_marks: 60
    )

    question_a = Question.create!(content: "What is include function?", difficulty: "Easy", marks: 2, entry_mode: "typed", subject: subject)
    question_b = Question.create!(content: "Explain mysql_connect() function with example.", difficulty: "Medium", marks: 6, entry_mode: "typed", subject: subject)
    question_c = Question.create!(content: "What is Constructor in PHP? Explain it with an example.", difficulty: "Hard", marks: 8, entry_mode: "typed", subject: subject)

    PaperQuestion.create!(paper: paper, question: question_a)
    PaperQuestion.create!(paper: paper, question: question_b)
    PaperQuestion.create!(paper: paper, question: question_c)

    get view_paper_url(id: paper.id)

    assert_response :success
    assert_match "CHRIST COLLEGE", response.body
    assert_match "OF SCIENCE AND MANAGEMENT", response.body
    assert_match "III BCA MODEL EXAMINATION - JUNE 2024", response.body
    assert_match "PHP &amp; MYSQL", response.body
    assert_match "Section- A", response.body
    assert_match "Section- B", response.body
    assert_match "Section- C", response.body
    assert_match "(1 X 2 = 2 Marks)", response.body
    assert_match "(1 X 6 = 6 Marks)", response.body
    assert_match "(1 X 8 = 8 Marks)", response.body
    assert_match(/<ol class="question-list">\s*<li class="question-item">/m, response.body)
    assert_no_match "Subject Expert Signature", response.body
  end

  test "should import questions from csv" do
    sign_in
    subject = Subject.create!(name: "Data Structures", code: "CS101", department: "BCA", semester: "Semester 1")

    post import_questions_url, params: {
      subject_id: subject.id,
      file: build_uploaded_file(
        "content,section,unit\nWhat is a stack?,A,1\n",
        "text/csv",
        original_filename: "questions.csv"
      )
    }

    assert_redirected_to pages_question_bank_url
    question = Question.order(:created_at).last
    assert_equal "What is a stack?", question.content
    assert_equal "1", question.unit
    assert_equal 2, question.marks
    assert_equal "questions.csv", question.import_source_name
    assert question.import_batch_id.present?
  end

  test "question bank shows imported files instead of each imported question" do
    sign_in
    subject = Subject.create!(name: "Data Structures", code: "CS101", department: "BCA", semester: "Semester 1")
    batch_id = "batch-001"

    Question.create!(
      content: "What is a stack?",
      difficulty: "Easy",
      marks: 2,
      unit: "1",
      subject: subject,
      entry_mode: "imported",
      import_batch_id: batch_id,
      import_source_name: "questions.csv"
    )
    Question.create!(
      content: "What is a queue?",
      difficulty: "Medium",
      marks: 6,
      unit: "1",
      subject: subject,
      entry_mode: "imported",
      import_batch_id: batch_id,
      import_source_name: "questions.csv"
    )

    get pages_question_bank_url

    assert_response :success
    assert_match "questions.csv", response.body
    assert_match "2 Questions", response.body
    assert_no_match "What is a stack?", response.body
    assert_no_match "What is a queue?", response.body
  end

  test "should delete all questions from an imported file batch" do
    sign_in
    subject = Subject.create!(name: "Data Structures", code: "CS101", department: "BCA", semester: "Semester 1")

    2.times do |index|
      Question.create!(
        content: "Imported question #{index}",
        difficulty: "Easy",
        marks: 2,
        unit: "1",
        subject: subject,
        entry_mode: "imported",
        import_batch_id: "batch-delete",
        import_source_name: "questions.csv"
      )
    end

    assert_difference("Question.count", -2) do
      delete delete_import_batch_url(group_key: "batch:batch-delete")
    end

    assert_redirected_to pages_question_bank_url
    assert_equal 0, Question.for_import_batch("batch-delete").count
  end

  test "question bank keeps repeated imports of the same filename as separate files" do
    sign_in
    subject = Subject.create!(name: "Data Structures", code: "CS101", department: "BCA", semester: "Semester 1")

    2.times do |index|
      post import_questions_url, params: {
        subject_id: subject.id,
        file: build_uploaded_file(
          "content,section,unit\nImported question #{index},A,1\n",
          "text/csv",
          original_filename: "questions.csv"
        )
      }
    end

    get pages_question_bank_url

    assert_response :success
    assert_match "2 Files", response.body
    assert_equal 2, Question.imported_entries.select(:import_batch_id).distinct.count
    assert_equal 2, response.body.scan("questions.csv").length
  end

  test "deleting one imported file keeps other files with the same filename" do
    sign_in
    subject = Subject.create!(name: "Data Structures", code: "CS101", department: "BCA", semester: "Semester 1")

    first_batch = "batch-001"
    second_batch = "batch-002"

    Question.create!(
      content: "Imported question 1",
      difficulty: "Easy",
      marks: 2,
      unit: "1",
      subject: subject,
      entry_mode: "imported",
      import_batch_id: first_batch,
      import_source_name: "questions.csv"
    )
    Question.create!(
      content: "Imported question 2",
      difficulty: "Easy",
      marks: 2,
      unit: "1",
      subject: subject,
      entry_mode: "imported",
      import_batch_id: second_batch,
      import_source_name: "questions.csv"
    )

    assert_difference("Question.count", -1) do
      delete delete_import_batch_url(group_key: "batch:#{first_batch}")
    end

    assert_redirected_to pages_question_bank_url
    assert_equal 0, Question.for_import_batch(first_batch).count
    assert_equal 1, Question.for_import_batch(second_batch).count
  end

  test "question bank shows delete icon for imported files without batch id" do
    sign_in
    subject = Subject.create!(name: "Data Structures", code: "CS101", department: "BCA", semester: "Semester 1")

    Question.create!(
      content: "Legacy imported question",
      difficulty: "Easy",
      marks: 2,
      unit: "1",
      subject: subject,
      entry_mode: "imported",
      import_batch_id: nil,
      import_source_name: "legacy.csv"
    )

    get pages_question_bank_url

    assert_response :success
    assert_match CGI.escapeHTML(delete_import_batch_path(group_key: "source:legacy.csv")), response.body
  end

  test "should delete imported file by source name when batch id is missing" do
    sign_in
    subject = Subject.create!(name: "Data Structures", code: "CS101", department: "BCA", semester: "Semester 1")

    2.times do |index|
      Question.create!(
        content: "Legacy imported question #{index}",
        difficulty: "Easy",
        marks: 2,
        unit: "1",
        subject: subject,
        entry_mode: "imported",
        import_batch_id: nil,
        import_source_name: "legacy.csv"
      )
    end

    assert_difference("Question.count", -2) do
      delete delete_import_batch_url(group_key: "source:legacy.csv")
    end

    assert_redirected_to pages_question_bank_url
    assert_equal 0, Question.imported_entries.where(import_batch_id: nil, import_source_name: "legacy.csv").count
  end

  test "should import questions from docx" do
    sign_in
    subject = Subject.create!(name: "Algorithms", code: "CS102", department: "BCA", semester: "Semester 2")
    docx = build_docx(<<~TEXT)
      Unit: 2
      Section: B
      Explain recursion.
      1. Explain divide and conquer.
    TEXT

    post import_questions_url, params: {
      subject_id: subject.id,
      file: build_uploaded_file(
        docx,
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        original_filename: "questions.docx"
      )
    }

    assert_redirected_to pages_question_bank_url
    questions = Question.order(:created_at).last(2)
    assert_equal [ "Explain recursion.", "Explain divide and conquer." ], questions.map(&:content)
    assert_equal [ "2", "2" ], questions.map(&:unit)
    assert_equal [ 6, 6 ], questions.map(&:marks)
  end

  test "should import questions from teacher style docx headings" do
    sign_in
    subject = Subject.create!(name: "Programming", code: "CS103", department: "BCA", semester: "Semester 1")
    docx = build_docx(<<~TEXT)
      Unit One
      Section A
      What is a program?
      What is an interpreter?

      Section B
      Explain compilation.

      Section C
      Design a simple calculator flow.
    TEXT

    post import_questions_url, params: {
      subject_id: subject.id,
      file: build_uploaded_file(
        docx,
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        original_filename: "teacher-questions.docx"
      )
    }

    assert_redirected_to pages_question_bank_url
    questions = Question.order(:created_at).last(4)
    assert_equal(
      [
        "What is a program?",
        "What is an interpreter?",
        "Explain compilation.",
        "Design a simple calculator flow."
      ],
      questions.map(&:content)
    )
    assert_equal [ "One", "One", "One", "One" ], questions.map(&:unit)
    assert_equal [ 2, 2, 6, 8 ], questions.map(&:marks)
  end

  test "should import questions from docx with flexible section heading formats" do
    sign_in
    subject = Subject.create!(name: "Networking", code: "CS104", department: "BCA", semester: "Semester 3")
    docx = build_docx(<<~TEXT)
      Unit 3
      SECTION : A
      What is a protocol?

      Section-B
      Explain OSI model.

      Section C:
      Design a subnetting plan.
    TEXT

    post import_questions_url, params: {
      subject_id: subject.id,
      file: build_uploaded_file(
        docx,
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        original_filename: "flexible-sections.docx"
      )
    }

    assert_redirected_to pages_question_bank_url
    questions = Question.order(:created_at).last(3)
    assert_equal(
      [
        "What is a protocol?",
        "Explain OSI model.",
        "Design a subnetting plan."
      ],
      questions.map(&:content)
    )
    assert_equal [ 2, 6, 8 ], questions.map(&:marks)
  end

  test "should import college question bank docx with preamble and continuation lines" do
    sign_in
    subject = Subject.create!(name: "PHP & MYSQL", code: "BCA601", department: "BCA", semester: "Semester 6")
    docx = build_docx(<<~TEXT)
      VI SEM BCA(NEP)
      PHP &MYSQL QUESTION BANK
      UNIT 1
      SECTION A -2 Marks
      1.What are keywords? Give an example.
      What is PHP?
      List any two features of PHP
      SECTION C-8 Marks
      Write a complete PHP program to:
      Connect to MySQL
      Create a table
      Insert records
      Display records
    TEXT

    post import_questions_url, params: {
      subject_id: subject.id,
      file: build_uploaded_file(
        docx,
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        original_filename: "qp-bank.docx"
      )
    }

    assert_redirected_to pages_question_bank_url
    questions = Question.order(:created_at).last(4)
    assert_equal(
      [
        "What are keywords? Give an example.",
        "What is PHP?",
        "List any two features of PHP",
        "Write a complete PHP program to: Connect to MySQL Create a table Insert records Display records"
      ],
      questions.map(&:content)
    )
    assert_equal [ "1", "1", "1", "1" ], questions.map(&:unit)
    assert_equal [ 2, 2, 2, 8 ], questions.map(&:marks)
  end

  test "should generate a paper with balanced unit coverage inside each section" do
    sign_in
    subject = Subject.create!(name: "Operating Systems", code: "BCA501", department: "BCA", semester: "Semester 5")

    %w[1 2 3].each do |unit|
      Question.create!(content: "Section A #{unit}", difficulty: "Easy", marks: 2, unit: unit, entry_mode: "typed", subject: subject)
      Question.create!(content: "Section B #{unit}", difficulty: "Medium", marks: 6, unit: unit, entry_mode: "typed", subject: subject)
      Question.create!(content: "Section C #{unit}", difficulty: "Hard", marks: 8, unit: unit, entry_mode: "typed", subject: subject)
    end

    post create_paper_url, params: {
      title: "Model Exam",
      exam_type: "Model Exam",
      subject_id: subject.id,
      duration: "3 Hours",
      total_marks: 26,
      section_a_count: 3,
      section_b_count: 2,
      section_c_count: 1
    }

    paper = Paper.order(:created_at).last
    assert_redirected_to view_paper_url(id: paper.id)

    questions = paper.questions
    assert_equal 6, questions.count
    assert_equal 3, questions.select { |question| question.section_name == "A" }.map(&:unit).uniq.size
    assert_equal 2, questions.select { |question| question.section_name == "B" }.map(&:unit).uniq.size
    assert_equal 1, questions.select { |question| question.section_name == "C" }.count
  end

  test "should generate a paper only from the selected units" do
    sign_in
    subject = Subject.create!(name: "Computer Networks", code: "BCA502", department: "BCA", semester: "Semester 5")

    %w[1 2 3].each do |unit|
      Question.create!(content: "Section A #{unit}", difficulty: "Easy", marks: 2, unit: unit, entry_mode: "typed", subject: subject)
      Question.create!(content: "Section B #{unit}", difficulty: "Medium", marks: 6, unit: unit, entry_mode: "typed", subject: subject)
      Question.create!(content: "Section C #{unit}", difficulty: "Hard", marks: 8, unit: unit, entry_mode: "typed", subject: subject)
    end

    post create_paper_url, params: {
      title: "Internal Exam",
      exam_type: "First Internal",
      subject_id: subject.id,
      duration: "3 Hours",
      total_marks: 18,
      section_a_count: 2,
      section_b_count: 1,
      section_c_count: 1,
      unit_filter_present: "1",
      units: [ "1", "2" ]
    }

    paper = Paper.order(:created_at).last
    assert_redirected_to view_paper_url(id: paper.id)

    assert_equal [ "1", "2" ], paper.questions.map(&:unit).uniq.sort
  end

  private

  def sign_in
    post pages_login_url, params: {
      session: {
        email: @user.email,
        password: "Password123"
      }
    }
  end

  def build_uploaded_file(content, mime_type, original_filename:)
    tempfile = Tempfile.new("upload")
    tempfile.binmode
    tempfile.write(content)
    tempfile.rewind

    Rack::Test::UploadedFile.new(
      tempfile.path,
      mime_type,
      true,
      original_filename: original_filename
    )
  end

  def build_docx(text)
    buffer = Zip::OutputStream.write_buffer do |zip|
      zip.put_next_entry("[Content_Types].xml")
      zip.write(<<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
          <Default Extension="xml" ContentType="application/xml"/>
          <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        </Types>
      XML

      zip.put_next_entry("_rels/.rels")
      zip.write(<<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
      XML

      zip.put_next_entry("word/document.xml")
      zip.write(docx_document_xml(text))
    end

    buffer.string
  end

  def docx_document_xml(text)
    body = text.each_line.map do |line|
      next if line.strip.empty?

      escaped = CGI.escapeHTML(line.strip)
      "<w:p><w:r><w:t>#{escaped}</w:t></w:r></w:p>"
    end.compact.join

    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>#{body}</w:body>
      </w:document>
    XML
  end
end
