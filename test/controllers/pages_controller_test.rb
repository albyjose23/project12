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
    assert_match "Manual Randomizer", response.body
    assert_match 'name="units[]"', response.body
    assert_match "Unit 5", response.body
    assert_no_match(/name="units\[\]".*checked/m, response.body)
    assert_match(/data-randomizer-mode-target="manualPanel"/, response.body)
    assert_match(/class="panel hidden"/, response.body)
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
      1. Explain divide and conquer.
      This answer should include recurrence relations. It can span lines.
      2. Explain recursion.
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
    assert_equal(
      [
        "Explain divide and conquer. This answer should include recurrence relations. It can span lines.",
        "Explain recursion."
      ],
      questions.map(&:content)
    )
    assert_equal [ "Unit 2", "Unit 2" ], questions.map(&:unit)
    assert_equal [ 6, 6 ], questions.map(&:marks)
  end

  test "should import docx when section c questions are in a single paragraph" do
    sign_in
    subject = Subject.create!(name: "Database Systems", code: "CS105", department: "BCA", semester: "Semester 4")
    docx = build_docx_paragraphs([
      "UNIT 2:",
      "Section C - 8 Marks",
      "1. Explain normalization in detail. 2. Explain indexing with example. 3. Explain transactions and ACID properties."
    ])

    post import_questions_url, params: {
      subject_id: subject.id,
      file: build_uploaded_file(
        docx,
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        original_filename: "section-c-single-paragraph.docx"
      )
    }

    assert_redirected_to pages_question_bank_url
    questions = Question.order(:created_at).last(3)
    assert_equal(
      [
        "Explain normalization in detail.",
        "Explain indexing with example.",
        "Explain transactions and ACID properties."
      ],
      questions.map(&:content)
    )
    assert_equal [ 8, 8, 8 ], questions.map(&:marks)
    assert_equal [ "Unit 2", "Unit 2", "Unit 2" ], questions.map(&:unit)
  end

  test "should import docx with bracket numbering and leading spaces" do
    sign_in
    subject = Subject.create!(name: "C Programming", code: "CS106", department: "BCA", semester: "Semester 1")
    docx = build_docx_paragraphs([
      "UNIT I",
      "Section A - 2 Marks",
      " 1 ) What is an algorithm?",
      " 2 . What is a flowchart?"
    ])

    post import_questions_url, params: {
      subject_id: subject.id,
      file: build_uploaded_file(
        docx,
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        original_filename: "flexible-numbering.docx"
      )
    }

    assert_redirected_to pages_question_bank_url
    questions = Question.order(:created_at).last(2)
    assert_equal [ "What is an algorithm?", "What is a flowchart?" ], questions.map(&:content)
    assert_equal [ "Unit 1", "Unit 1" ], questions.map(&:unit)
    assert_equal [ 2, 2 ], questions.map(&:marks)
  end

  test "should import questions from teacher style docx headings with numbered lines" do
    sign_in
    subject = Subject.create!(name: "Programming", code: "CS103", department: "BCA", semester: "Semester 1")
    docx = build_docx(<<~TEXT)
      Unit One
      Section A
      1. What is a program?
      2. What is an interpreter?

      Section B
      1. Explain compilation.

      Section C
      1. Design a simple calculator flow.
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
    assert_equal [ "Unit 1", "Unit 1", "Unit 1", "Unit 1" ], questions.map(&:unit)
    assert_equal [ 2, 2, 6, 8 ], questions.map(&:marks)
  end

  test "should import docx only when numbered questions appear inside the section" do
    sign_in
    subject = Subject.create!(name: "Data Structures", code: "CS107", department: "BCA", semester: "Semester 2")
    docx = build_docx(<<~TEXT)
      Unit One
      Section A
      What is a stack?
      What is a queue?

      Section B
      Explain linked lists.

      Section C
      Design a tree traversal algorithm.
      1. Build a binary tree traversal algorithm.
    TEXT

    post import_questions_url, params: {
      subject_id: subject.id,
      file: build_uploaded_file(
        docx,
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        original_filename: "teacher-questions-unnumbered.docx"
      )
    }

    assert_redirected_to pages_question_bank_url
    questions = Question.order(:created_at).last(1)
    assert_equal(
      [
        "Design a tree traversal algorithm. Build a binary tree traversal algorithm."
      ],
      questions.map(&:content)
    )
    assert_equal [ "Unit 1" ], questions.map(&:unit)
    assert_equal [ 8 ], questions.map(&:marks)
  end

  test "should import questions from docx with flexible section heading formats" do
    sign_in
    subject = Subject.create!(name: "Networking", code: "CS104", department: "BCA", semester: "Semester 3")
    docx = build_docx(<<~TEXT)
      Unit 3
      SECTION : A
      1. What is a protocol?

      Section-B
      1. Explain OSI model.

      Section C:
      1. Design a subnetting plan.
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
      2. What is PHP?
      3. List any two features of PHP
      SECTION C-8 Marks
      1. Write a complete PHP program to:
      Connect to MySQL.
      Create a table.
      Insert records.
      Display records.
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
        "Write a complete PHP program to: Connect to MySQL. Create a table. Insert records. Display records."
      ],
      questions.map(&:content)
    )
    assert_equal [ "Unit 1", "Unit 1", "Unit 1", "Unit 1" ], questions.map(&:unit)
    assert_equal [ 2, 2, 2, 8 ], questions.map(&:marks)
  end

  test "should generate a paper with random filtered questions across selected units" do
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
    assert_equal 3, questions.select { |question| question.section_name == "A" }.count
    assert_equal 2, questions.select { |question| question.section_name == "B" }.count
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

  test "should generate 8 mark questions from only the two selected imported units" do
    sign_in
    subject = Subject.create!(name: "Microprocessors", code: "BCA503", department: "BCA", semester: "Semester 5")
    docx = build_docx(<<~TEXT)
      UNIT 1
      SECTION C-8 Marks
      1. Design an 8086 assembly routine.

      UNIT 2
      SECTION C-8 Marks
      1. Explain memory segmentation in detail.

      UNIT 3
      SECTION C-8 Marks
      1. Explain interrupt handling in 8086.
    TEXT

    post import_questions_url, params: {
      subject_id: subject.id,
      file: build_uploaded_file(
        docx,
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        original_filename: "microprocessors-section-c.docx"
      )
    }

    assert_redirected_to pages_question_bank_url

    post create_paper_url, params: {
      title: "Section C Only",
      exam_type: "Model Exam",
      subject_id: subject.id,
      duration: "3 Hours",
      total_marks: 16,
      section_a_count: 0,
      section_b_count: 0,
      section_c_count: 2,
      unit_filter_present: "1",
      units: [ "1", "2" ]
    }

    paper = Paper.order(:created_at).last
    assert_redirected_to view_paper_url(id: paper.id)
    assert_equal [ 8, 8 ], paper.questions.order(:id).map(&:marks)
    assert_equal [ "Unit 1", "Unit 2" ], paper.questions.map(&:unit).uniq.sort
  end

  test "should generate a paper with exact per-unit manual randomizer counts" do
    sign_in
    subject = Subject.create!(name: "Compiler Design", code: "BCA504", department: "BCA", semester: "Semester 5")

    3.times do |index|
      Question.create!(content: "Unit 1 Section A #{index}", difficulty: "Easy", marks: 2, unit: "1", entry_mode: "typed", subject: subject)
    end
    2.times do |index|
      Question.create!(content: "Unit 1 Section B #{index}", difficulty: "Medium", marks: 6, unit: "1", entry_mode: "typed", subject: subject)
    end
    Question.create!(content: "Unit 1 Section C 0", difficulty: "Hard", marks: 8, unit: "1", entry_mode: "typed", subject: subject)
    2.times do |index|
      Question.create!(content: "Unit 2 Section A #{index}", difficulty: "Easy", marks: 2, unit: "2", entry_mode: "typed", subject: subject)
    end
    Question.create!(content: "Unit 2 Section B 0", difficulty: "Medium", marks: 6, unit: "2", entry_mode: "typed", subject: subject)
    2.times do |index|
      Question.create!(content: "Unit 2 Section C #{index}", difficulty: "Hard", marks: 8, unit: "2", entry_mode: "typed", subject: subject)
    end

    post create_paper_url, params: {
      title: "Manual Randomizer Paper",
      exam_type: "Model Exam",
      subject_id: subject.id,
      duration: "3 Hours",
      total_marks: 28,
      generator_mode: "manual",
      unit_filter_present: "1",
      units: [ "1", "2" ],
      manual_section_counts: {
        "1" => { "A" => 2, "B" => 1, "C" => 1 },
        "2" => { "A" => 1, "B" => 0, "C" => 1 }
      }
    }

    paper = Paper.order(:created_at).last
    assert_redirected_to view_paper_url(id: paper.id)

    grouped = paper.questions.group_by { |question| [ Question.normalize_unit_value(question.unit), question.section_name ] }
    assert_equal 2, grouped.fetch([ "1", "A" ]).size
    assert_equal 1, grouped.fetch([ "1", "B" ]).size
    assert_equal 1, grouped.fetch([ "1", "C" ]).size
    assert_equal 1, grouped.fetch([ "2", "A" ]).size
    assert_equal 1, grouped.fetch([ "2", "C" ]).size
    assert_nil grouped[[ "2", "B" ]]
  end

  test "manual randomizer should validate per-unit section availability" do
    sign_in
    subject = Subject.create!(name: "Java Programming", code: "BCA505", department: "BCA", semester: "Semester 5")
    Question.create!(content: "Unit 1 Section A", difficulty: "Easy", marks: 2, unit: "1", entry_mode: "typed", subject: subject)

    assert_no_difference("Paper.count") do
      post create_paper_url, params: {
        title: "Manual Randomizer Paper",
        exam_type: "First Internal",
        subject_id: subject.id,
        duration: "3 Hours",
        total_marks: 4,
        generator_mode: "manual",
        unit_filter_present: "1",
        units: [ "1" ],
        manual_section_counts: {
          "1" => { "A" => 2, "B" => 0, "C" => 0 }
        }
      }
    end

    assert_redirected_to pages_generate_paper_url
    assert_equal "Only 1 question(s) available for Unit 1 Section A", flash[:alert]
  end

  test "manual randomizer keeps only selected unit counts in form state after redirect" do
    sign_in
    subject = Subject.create!(name: "Python", code: "BCA506", department: "BCA", semester: "Semester 5")
    Question.create!(content: "Unit 1 Section A", difficulty: "Easy", marks: 2, unit: "1", entry_mode: "typed", subject: subject)

    post create_paper_url, params: {
      title: "Manual Randomizer Paper",
      exam_type: "First Internal",
      subject_id: subject.id,
      duration: "3 Hours",
      total_marks: 10,
      generator_mode: "manual",
      unit_filter_present: "1",
      units: [ "1", "2" ],
      manual_section_counts: {
        "1" => { "A" => 2, "B" => 0, "C" => 0 },
        "2" => { "A" => 3, "B" => 5, "C" => 0 },
        "3" => { "A" => 9, "B" => 9, "C" => 9 }
      }
    }

    assert_redirected_to pages_generate_paper_url

    follow_redirect!
    assert_response :success
    assert_match 'name="manual_section_counts[1][A]"', response.body
    assert_match 'value="2"', response.body
    assert_match 'name="manual_section_counts[2][B]"', response.body
    assert_match 'value="5"', response.body
    assert_no_match 'name="manual_section_counts[3][A]" value="9"', response.body
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
    build_docx_paragraphs(text.each_line.filter_map do |line|
      stripped = line.strip
      stripped.presence
    end)
  end

  def build_docx_paragraphs(paragraphs)
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
      zip.write(docx_document_xml(paragraphs))
    end

    buffer.string
  end

  def docx_document_xml(paragraphs)
    body = Array(paragraphs).map do |paragraph|
      escaped = CGI.escapeHTML(paragraph.to_s)
      "<w:p><w:r><w:t>#{escaped}</w:t></w:r></w:p>"
    end.join

    <<~XML
      <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
      <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:body>#{body}</w:body>
      </w:document>
    XML
  end
end
