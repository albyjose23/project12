require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create!(
      name: "Test Faculty",
      email: "faculty@example.com",
      department: "BCA",
      role: "Professor",
      password: "Password123",
      password_confirmation: "Password123"
    )
  end

  test "should get register" do
    get pages_register_url
    assert_response :success
  end

  test "should get login" do
    get pages_login_url
    assert_response :success
  end

  test "should register a user" do
    post pages_register_url, params: {
      user: {
        name: "New Faculty",
        email: "new@example.com",
        department: "BCA",
        role: "Professor",
        password: "Password123",
        password_confirmation: "Password123"
      }
    }

    assert_redirected_to pages_dashboard_url
  end

  test "should allow registered user to log in" do
    post pages_login_url, params: {
      session: {
        email: @user.email,
        password: "Password123"
      }
    }

    assert_redirected_to pages_dashboard_url
  end

  test "should reject invalid login" do
    post pages_login_url, params: {
      session: {
        email: @user.email,
        password: "wrong-password"
      }
    }

    assert_response :unprocessable_entity
  end

  test "should redirect unauthenticated dashboard access" do
    get pages_dashboard_url
    assert_redirected_to pages_login_url
  end

  test "should get dashboard when logged in" do
    sign_in
    get pages_dashboard_url
    assert_response :success
  end

  test "should get manage_subjects when logged in" do
    sign_in
    get pages_manage_subjects_url
    assert_response :success
  end

  test "should get question_bank when logged in" do
    sign_in
    get pages_question_bank_url
    assert_response :success
  end

  test "should get generate_paper when logged in" do
    sign_in
    get pages_generate_paper_url
    assert_response :success
  end

  test "should get generated_papers when logged in" do
    sign_in
    get pages_generated_papers_url
    assert_response :success
  end

  test "should get view_paper when logged in" do
    sign_in
    paper = Paper.create!(title: "Sample Paper", subject: Subject.create!(name: "Data Structures", code: "CS101", department: "BCA", semester: "Semester 1"))
    get view_paper_url(id: paper.id)
    assert_response :success
  end

  private

  def sign_in
    post pages_login_url, params: {
      session: {
        email: @user.email,
        password: "Password123"
      }
    }
  end
end
