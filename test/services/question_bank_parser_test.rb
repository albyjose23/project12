require "test_helper"

class QuestionBankParserTest < ActiveSupport::TestCase
  test "parses numbered questions under unit and section headings" do
    rows = QuestionBankParser.parse([
      "UNIT 1",
      "Section A",
      "1. What is PHP?",
      "2. What is XAMPP?"
    ])

    assert_equal 2, rows.size
    assert_equal "Unit 1", rows[0]["unit"]
    assert_equal "A", rows[0]["section"]
    assert_equal 1, rows[0]["question_no"]
    assert_equal "What is PHP?", rows[0]["text"]
  end

  test "preserves multi line questions and does not split on periods" do
    rows = QuestionBankParser.parse([
      "Unit II",
      "Section B",
      "1. Explain recursion. Why is it useful.",
      "Write one example. Mention the base condition.",
      "2. Explain iteration."
    ])

    assert_equal 2, rows.size
    assert_equal "Unit 2", rows[0]["unit"]
    assert_equal "Explain recursion. Why is it useful. Write one example. Mention the base condition.", rows[0]["text"]
  end

  test "keeps introductory lines when a numbered long answer continues below" do
    rows = QuestionBankParser.parse([
      "Unit-3",
      "Section C",
      "Answer all questions",
      "8 Marks",
      "Write a complete program to do the following:",
      "1. Connect to MySQL.",
      "Insert records.",
      "Display records."
    ])

    assert_equal 1, rows.size
    assert_equal "Unit 3", rows[0]["unit"]
    assert_equal "C", rows[0]["section"]
    assert_equal 1, rows[0]["question_no"]
    assert_equal "Write a complete program to do the following: Connect to MySQL. Insert records. Display records.", rows[0]["text"]
  end

  test "accepts flexible numbering styles with spaces and closing brackets" do
    rows = QuestionBankParser.parse([
      "UNIT 5",
      "Section A - 2 Marks",
      " 1 ) Define compiler.",
      " 2 . Define interpreter."
    ])

    assert_equal 2, rows.size
    assert_equal [ 1, 2 ], rows.map { |row| row["question_no"] }
    assert_equal [ "Define compiler.", "Define interpreter." ], rows.map { |row| row["text"] }
  end

  test "detects unit and section when they appear in longer paragraphs" do
    rows = QuestionBankParser.parse([
      "BCA QUESTION BANK UNIT 2",
      "Section C - 8 Marks",
      "1. Explain transactions."
    ])

    assert_equal 1, rows.size
    assert_equal "Unit 2", rows[0]["unit"]
    assert_equal "C", rows[0]["section"]
    assert_equal "Explain transactions.", rows[0]["text"]
  end

  test "splits repeated serial numbers inside the same paragraph" do
    rows = QuestionBankParser.parse([
      "UNIT 1",
      "Section C",
      "1. Explain normalization in detail. 2. Explain indexing with example. 3. Explain transactions and ACID properties."
    ])

    assert_equal 3, rows.size
    assert_equal [ 1, 2, 3 ], rows.map { |row| row["question_no"] }
    assert_equal(
      [
        "Explain normalization in detail.",
        "Explain indexing with example.",
        "Explain transactions and ACID properties."
      ],
      rows.map { |row| row["text"] }
    )
  end

  test "splits questions using serial numbers even without punctuation markers" do
    rows = QuestionBankParser.parse([
      "UNIT 4",
      "Section B",
      "1 Explain compiler design 2 Explain parser phases 3 Explain code generation"
    ])

    assert_equal 3, rows.size
    assert_equal [ 1, 2, 3 ], rows.map { |row| row["question_no"] }
    assert_equal(
      [
        "Explain compiler design",
        "Explain parser phases",
        "Explain code generation"
      ],
      rows.map { |row| row["text"] }
    )
  end

  test "infers separate questions from consecutive unnumbered paragraphs" do
    rows = QuestionBankParser.parse([
      "Unit One",
      "Section A",
      "What is a program?",
      "What is an interpreter?",
      "Section B",
      "Explain compilation.",
      "Section C",
      "Design a simple calculator flow.",
      "1. Build a calculator flow chart."
    ])

    assert_equal 4, rows.size
    assert_equal [ "A", "A", "B", "C" ], rows.map { |row| row["section"] }
    assert_equal [ 1, 2, 1, 1 ], rows.map { |row| row["question_no"] }
    assert_equal "What is a program?", rows[0]["text"]
    assert_equal "What is an interpreter?", rows[1]["text"]
    assert_equal "Explain compilation.", rows[2]["text"]
    assert_equal "Design a simple calculator flow. Build a calculator flow chart.", rows[3]["text"]
  end

  test "parses uploaded docx style sections with unnumbered long-answer questions" do
    rows = QuestionBankParser.parse([
      "UNIT 2:Web Hosting",
      "Section B – 6 Marks",
      "1. Explain different types of web hosting services with examples.",
      "2. Explain the steps involved in creating a Wiki site.",
      "Section C – 8 Marks",
      "Explain the step-by-step process of creating and maintaining a Wiki site with examples..",
      "Describe the features, tools, and best practices for creating effective presentations using software like PowerPoint or Google Slides.",
      "Discuss the importance of multilingual content development in global communication. How can businesses and websites implement it effectively?."
    ])

    section_c_rows = rows.select { |row| row["section"] == "C" }

    assert_equal 5, rows.size
    assert_equal 3, section_c_rows.size
    assert_equal [ 1, 2, 3 ], section_c_rows.map { |row| row["question_no"] }
    assert_equal(
      [
        "Explain the step-by-step process of creating and maintaining a Wiki site with examples..",
        "Describe the features, tools, and best practices for creating effective presentations using software like PowerPoint or Google Slides.",
        "Discuss the importance of multilingual content development in global communication. How can businesses and websites implement it effectively?."
      ],
      section_c_rows.map { |row| row["text"] }
    )
  end
end
