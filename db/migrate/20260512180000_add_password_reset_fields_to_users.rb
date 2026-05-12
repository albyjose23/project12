class AddPasswordResetFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_reset_token_digest, :string
    add_column :users, :password_reset_expires_at, :datetime
    add_index :users, :password_reset_token_digest, unique: true
  end
end
