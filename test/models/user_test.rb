require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "set_display_name populates from first_name and last initial" do
    user = User.new(email_address: "john@example.com", password: "password", first_name: "John", last_name: "Doe")
    user.valid?
    assert_equal "John D", user.display_name
  end

  test "set_display_name does not overwrite when display_name present" do
    user = User.new(email_address: "j@example.com", password: "password", first_name: "John", last_name: "Doe", display_name: "Johnny")
    user.valid?
    assert_equal "Johnny", user.display_name
  end

  test "set_display_name does nothing when both names blank" do
    user = User.new(email_address: "x@example.com", password: "password")
    user.valid?
    assert_nil user.display_name
  end

  test "teller_number upcased and stripped" do
    user = User.new(email_address: "t@example.com", password: "password", teller_number: " t001 ")
    assert_equal "T001", user.teller_number
  end

  test "teller_number validates max length 4" do
    user = User.new(email_address: "long@example.com", password: "password", teller_number: "T0012")
    assert_not user.valid?
    assert_includes user.errors[:teller_number], "is too long (maximum is 4 characters)"
  end

  test "teller_number validates uniqueness" do
    existing = User.create!(email_address: "existing@example.com", password: "password", teller_number: "T001")
    user = User.new(email_address: "other@example.com", password: "password", teller_number: "T001")
    assert_not user.valid?
    assert_includes user.errors[:teller_number], "has already been taken"
  end

  test "teller_number allows blank" do
    user = User.new(email_address: "nofid@example.com", password: "password", teller_number: "")
    assert user.valid?
  end

  test "display_label returns display_name when present" do
    user = User.new(email_address: "d@example.com", display_name: "Jane D")
    assert_equal "Jane D", user.display_label
  end

  test "display_label returns email_address when display_name blank" do
    user = User.new(email_address: "fallback@example.com", display_name: nil)
    assert_equal "fallback@example.com", user.display_label
  end

  test "pin is hashed before storing in password_hash" do
    user = User.create!(email_address: "pin-test@example.com", password: "password", pin: "1234")
    assert user.password_hash.present?
    assert_not_equal "1234", user.password_hash
    assert user.authenticate_pin("1234")
    assert_not user.authenticate_pin("wrong")
  end

  test "authenticate_pin returns false when password_hash blank" do
    user = User.new(email_address: "no-pin@example.com")
    assert_not user.authenticate_pin("1234")
  end
end
