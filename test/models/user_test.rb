require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "email must be unique case insensitively" do
    User.create!(
      name: "Faculty One",
      email: "faculty@example.com",
      department: "BCA",
      role: "Professor",
      password: "Password123",
      password_confirmation: "Password123"
    )

    duplicate_user = User.new(
      name: "Faculty Two",
      email: "FACULTY@example.com",
      department: "BCA",
      role: "Professor",
      password: "Password123",
      password_confirmation: "Password123"
    )

    assert_not duplicate_user.valid?
    assert_includes duplicate_user.errors[:email], "has already been taken"
  end

  test "password must meet minimum length" do
    user = User.new(
      name: "Faculty",
      email: "faculty2@example.com",
      department: "BCA",
      role: "Professor",
      password: "short",
      password_confirmation: "short"
    )

    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  test "find_by_email_for_authentication normalizes email input" do
    user = User.create!(
      name: "Faculty",
      email: "faculty3@example.com",
      department: "BCA",
      role: "Professor",
      password: "Password123",
      password_confirmation: "Password123"
    )

    assert_equal user, User.find_by_email_for_authentication(" FACULTY3@example.com ")
  end
end
