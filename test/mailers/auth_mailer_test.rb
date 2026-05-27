require "test_helper"

class AuthMailerTest < ActionMailer::TestCase
  test "password_reset email generation" do
    user = User.create!(
      email: "reset_test@example.com",
      password: "Password123!",
      role: "patient",
      name: "Reset Tester"
    )
    raw_token = "abc123token"
    
    email = AuthMailer.password_reset(user, raw_token)
    
    assert_emails 1 do
      email.deliver_now
    end
    
    assert_equal ["reset_test@example.com"], email.to
    assert_equal "CareConnect — Reset Your Password", email.subject
    assert_match "Reset My Password", email.body.encoded
    assert_match raw_token, email.body.encoded
  end
end
