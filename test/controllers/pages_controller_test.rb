require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get register" do
    get pages_register_url
    assert_response :success
  end

  test "should get login" do
    get pages_login_url
    assert_response :success
  end

  test "should get dashboard" do
    get pages_dashboard_url
    assert_response :success
  end

  test "should get manage_subjects" do
    get pages_manage_subjects_url
    assert_response :success
  end

  test "should get question_bank" do
    get pages_question_bank_url
    assert_response :success
  end

  test "should get generate_paper" do
    get pages_generate_paper_url
    assert_response :success
  end

  test "should get generated_papers" do
    get pages_generated_papers_url
    assert_response :success
  end

  test "should get view_paper" do
    get pages_view_paper_url
    assert_response :success
  end
end
