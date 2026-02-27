# frozen_string_literal: true

require "test_helper"

module Teller
  class CredentialVerifierTest < ActiveSupport::TestCase
    setup do
      @user_with_both = User.create!(
        email_address: "both@example.com",
        password: "secret123",
        teller_number: "T01"
      )
      @user_with_both.update_column(:password_hash, BCrypt::Password.create("pin456").to_s)

      @user_email_only = User.create!(
        email_address: "email-only@example.com",
        password: "password99"
      )

      @user_teller_only = User.create!(
        email_address: "teller-only@example.com",
        password: "placeholder",
        teller_number: "T99"
      )
      @user_teller_only.update_column(:password_hash, BCrypt::Password.create("7890").to_s)
    end

    test "verifies email and password" do
      user = CredentialVerifier.verify(identifier: "both@example.com", secret: "secret123")
      assert_equal @user_with_both.id, user.id
    end

    test "verifies teller number and PIN" do
      user = CredentialVerifier.verify(identifier: "T01", secret: "pin456")
      assert_equal @user_with_both.id, user.id
    end

    test "verifies teller number case insensitively" do
      user = CredentialVerifier.verify(identifier: "t01", secret: "pin456")
      assert_equal @user_with_both.id, user.id
    end

    test "returns nil for wrong password" do
      assert_nil CredentialVerifier.verify(identifier: "both@example.com", secret: "wrong")
    end

    test "returns nil for wrong PIN" do
      assert_nil CredentialVerifier.verify(identifier: "T01", secret: "wrong")
    end

    test "returns nil for blank identifier" do
      assert_nil CredentialVerifier.verify(identifier: "", secret: "secret123")
      assert_nil CredentialVerifier.verify(identifier: "   ", secret: "secret123")
    end

    test "returns nil for blank secret" do
      assert_nil CredentialVerifier.verify(identifier: "both@example.com", secret: "")
      assert_nil CredentialVerifier.verify(identifier: "T01", secret: "")
    end

    test "returns nil for unknown email" do
      assert_nil CredentialVerifier.verify(identifier: "nobody@example.com", secret: "secret123")
    end

    test "returns nil for unknown teller number" do
      assert_nil CredentialVerifier.verify(identifier: "X99", secret: "pin456")
    end

    test "verifies user with email only" do
      user = CredentialVerifier.verify(identifier: "email-only@example.com", secret: "password99")
      assert_equal @user_email_only.id, user.id
    end

    test "verifies user with teller and PIN only" do
      user = CredentialVerifier.verify(identifier: "T99", secret: "7890")
      assert_equal @user_teller_only.id, user.id
    end
  end
end
