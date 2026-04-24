class CreatePaperQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :paper_questions do |t|
      t.references :paper, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true

      t.timestamps
    end
  end
end
