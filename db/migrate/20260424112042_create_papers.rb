class CreatePapers < ActiveRecord::Migration[8.1]
  def change
    create_table :papers do |t|
      t.string :title
      t.string :department
      t.string :semester
      t.string :exam_type
      t.references :subject, null: false, foreign_key: true

      t.timestamps
    end
  end
end
