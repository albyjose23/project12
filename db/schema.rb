# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_04_28_123000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "paper_questions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "paper_id", null: false
    t.bigint "question_id", null: false
    t.datetime "updated_at", null: false
    t.index ["paper_id"], name: "index_paper_questions_on_paper_id"
    t.index ["question_id"], name: "index_paper_questions_on_question_id"
  end

  create_table "papers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "duration"
    t.string "exam_type"
    t.text "instructions"
    t.bigint "subject_id", null: false
    t.string "title"
    t.integer "total_marks"
    t.datetime "updated_at", null: false
    t.index ["subject_id"], name: "index_papers_on_subject_id"
  end

  create_table "questions", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.string "difficulty"
    t.string "entry_mode", default: "typed", null: false
    t.integer "marks"
    t.bigint "subject_id", null: false
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["entry_mode"], name: "index_questions_on_entry_mode"
    t.index ["subject_id"], name: "index_questions_on_subject_id"
  end

  create_table "subjects", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.string "department"
    t.string "name"
    t.string "semester"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "department"
    t.string "email", null: false
    t.string "name"
    t.string "password_digest"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "paper_questions", "papers"
  add_foreign_key "paper_questions", "questions"
  add_foreign_key "papers", "subjects"
  add_foreign_key "questions", "subjects"
end
