class AddPaperDetailsToPapers < ActiveRecord::Migration[8.1]
  def change
    add_column :papers, :duration, :string
    add_column :papers, :instructions, :text
    add_column :papers, :total_marks, :integer
  end
end
