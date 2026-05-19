require "test_helper"

class Api::V1::UsersControllerTest < ActionDispatch::IntegrationTest
  test "should register a new patient user" do
    assert_difference('User.count') do
      post api_v1_users_path, params: {
        email: "test_patient@example.com",
        password: "SecurePass123!",
        role: "patient",
        name: "Test Patient",
        phone: "1234567890",
        date_of_birth: "1990-01-01"
      }
    end

    assert_response :created
    json_response = JSON.parse(response.body)
    assert_not_nil json_response["token"]
    assert_equal "Test Patient", json_response["user"]["name"]
  end

  test "should verify otp code successfully" do
    user = User.create!(email: "otp_test@example.com", password: "SecurePass123!", role: "patient", name: "OTP User")
    otp = user.generate_otp!

    post "/api/v1/users/verify_otp", params: {
      email: user.email,
      otp_code: otp
    }

    assert_response :ok
    user.reload
    assert user.email_verified
    assert_nil user.otp_code
  end

  test "should fail verify with invalid otp" do
    user = User.create!(email: "otp_fail@example.com", password: "SecurePass123!", role: "patient", name: "OTP Fail User")
    user.generate_otp!

    post "/api/v1/users/verify_otp", params: {
      email: user.email,
      otp_code: "000000"
    }

    assert_response :unprocessable_entity
    user.reload
    assert_not user.email_verified
  end

  test "should verify otp case insensitively" do
    user = User.create!(email: "UPPERCASE@example.com", password: "SecurePass123!", role: "patient", name: "Upper Case User")
    otp = user.generate_otp!

    post "/api/v1/users/verify_otp", params: {
      email: "uppercase@example.com",
      otp_code: otp
    }

    assert_response :ok
    user.reload
    assert user.email_verified
  end
end
