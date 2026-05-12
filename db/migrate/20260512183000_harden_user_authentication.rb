class HardenUserAuthentication < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE users
      SET email = lower(trim(email))
      WHERE email IS NOT NULL
    SQL

    add_column :users, :reset_password_token, :string unless column_exists?(:users, :reset_password_token)
    add_column :users, :reset_password_sent_at, :datetime unless column_exists?(:users, :reset_password_sent_at)

    if column_exists?(:users, :password_reset_token_digest)
      execute <<~SQL
        UPDATE users
        SET reset_password_token = password_reset_token_digest
        WHERE reset_password_token IS NULL
          AND password_reset_token_digest IS NOT NULL
      SQL
    end

    if column_exists?(:users, :password_reset_expires_at)
      execute <<~SQL
        UPDATE users
        SET reset_password_sent_at = password_reset_expires_at - INTERVAL '30 minutes'
        WHERE reset_password_sent_at IS NULL
          AND password_reset_expires_at IS NOT NULL
      SQL
    end

    remove_index :users, :email if index_exists?(:users, :email)
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email" unless index_exists?(:users, "lower(email)", unique: true, name: "index_users_on_lower_email")

    if index_exists?(:users, :password_reset_token_digest)
      remove_index :users, :password_reset_token_digest
    end
    add_index :users, :reset_password_token, unique: true unless index_exists?(:users, :reset_password_token)

    remove_column :users, :password_reset_token_digest, :string if column_exists?(:users, :password_reset_token_digest)
    remove_column :users, :password_reset_expires_at, :datetime if column_exists?(:users, :password_reset_expires_at)
  end

  def down
    add_column :users, :password_reset_token_digest, :string unless column_exists?(:users, :password_reset_token_digest)
    add_column :users, :password_reset_expires_at, :datetime unless column_exists?(:users, :password_reset_expires_at)

    execute <<~SQL
      UPDATE users
      SET password_reset_token_digest = reset_password_token
      WHERE password_reset_token_digest IS NULL
        AND reset_password_token IS NOT NULL
    SQL

    execute <<~SQL
      UPDATE users
      SET password_reset_expires_at = reset_password_sent_at + INTERVAL '30 minutes'
      WHERE password_reset_expires_at IS NULL
        AND reset_password_sent_at IS NOT NULL
    SQL

    remove_index :users, name: "index_users_on_lower_email" if index_exists?(:users, name: "index_users_on_lower_email")
    add_index :users, :email, unique: true unless index_exists?(:users, :email)

    remove_index :users, :reset_password_token if index_exists?(:users, :reset_password_token)
    add_index :users, :password_reset_token_digest, unique: true unless index_exists?(:users, :password_reset_token_digest)

    remove_column :users, :reset_password_token, :string if column_exists?(:users, :reset_password_token)
    remove_column :users, :reset_password_sent_at, :datetime if column_exists?(:users, :reset_password_sent_at)
  end
end
