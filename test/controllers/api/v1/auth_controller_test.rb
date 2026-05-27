require "test_helper"

class Api::V1::AuthControllerTest < ActionDispatch::IntegrationTest
  test "forgot password sends email for active user" do
    user = User.create!(
      email: "forgot_active@example.com",
      password: "Password123!",
      role: "patient",
      name: "Forgot Tester",
      active: true
    )

    assert_emails 1 do
      post "/api/v1/auth/forgot_password", params: { email: user.email }
    end

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_match "receive a reset link shortly", json_response["message"]
    
    user.reload
    assert_not_nil user.reset_password_token
    assert_not_nil user.reset_password_sent_at
  end

  test "forgot password does not send email for unregistered email" do
    assert_no_emails do
      post "/api/v1/auth/forgot_password", params: { email: "non_existent@example.com" }
    end

    assert_response :ok
    json_response = JSON.parse(response.body)
    assert_match "receive a reset link shortly", json_response["message"]
  end
end
