class AddEntryModeToQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :questions, :entry_mode, :string, null: false, default: "typed"
    add_index :questions, :entry_mode
  end
end
