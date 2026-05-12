class AddUserOwnershipToSubjectsQuestionsAndPapers < ActiveRecord::Migration[8.1]
  def up
    add_reference :subjects, :user, foreign_key: true
    add_reference :questions, :user, foreign_key: true
    add_reference :papers, :user, foreign_key: true

    say_with_time "Backfilling user ownership on existing records" do
      first_user_id = select_value("SELECT id FROM users ORDER BY id ASC LIMIT 1")

      execute <<~SQL.squish
        UPDATE subjects
        SET user_id = #{first_user_id}
        WHERE user_id IS NULL AND #{first_user_id.present? ? 'TRUE' : 'FALSE'}
      SQL

      execute <<~SQL.squish
        UPDATE questions
        SET user_id = COALESCE(questions.user_id, subjects.user_id, #{first_user_id || 'NULL'})
        FROM subjects
        WHERE questions.subject_id = subjects.id AND questions.user_id IS NULL
      SQL

      execute <<~SQL.squish
        UPDATE papers
        SET user_id = COALESCE(papers.user_id, subjects.user_id, #{first_user_id || 'NULL'})
        FROM subjects
        WHERE papers.subject_id = subjects.id AND papers.user_id IS NULL
      SQL
    end

    change_column_null :subjects, :user_id, false
    change_column_null :questions, :user_id, false
    change_column_null :papers, :user_id, false

  end

  def down
    remove_reference :papers, :user, foreign_key: true
    remove_reference :questions, :user, foreign_key: true
    remove_reference :subjects, :user, foreign_key: true
  end
end
