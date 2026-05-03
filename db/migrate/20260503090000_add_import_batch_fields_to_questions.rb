class AddImportBatchFieldsToQuestions < ActiveRecord::Migration[8.1]
  def change
    add_column :questions, :import_batch_id, :string
    add_column :questions, :import_source_name, :string
    add_index :questions, :import_batch_id
  end
end
