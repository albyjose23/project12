class AddExamTypeToPapers < ActiveRecord::Migration[8.1]
  def change
    add_column :papers, :exam_type, :string
  end
end
