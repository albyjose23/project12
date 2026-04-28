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
