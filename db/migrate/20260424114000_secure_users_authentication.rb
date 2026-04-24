class SecureUsersAuthentication < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_digest, :string unless column_exists?(:users, :password_digest)
    add_column :users, :department, :string unless column_exists?(:users, :department)
    add_column :users, :role, :string unless column_exists?(:users, :role)

    remove_column :users, :password, :string if column_exists?(:users, :password)

    execute <<~SQL
      DELETE FROM users older
      USING users newer
      WHERE lower(older.email) = lower(newer.email)
        AND older.id < newer.id
    SQL

    execute <<~SQL
      UPDATE users
      SET email = CONCAT('user-', id, '@qpaper.local')
      WHERE email IS NULL OR trim(email) = ''
    SQL

    change_column_null :users, :email, false
    add_index :users, :email, unique: true unless index_exists?(:users, :email)
  end
end
