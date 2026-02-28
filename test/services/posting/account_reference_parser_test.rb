# frozen_string_literal: true

require "test_helper"

module Posting
  class AccountReferenceParserTest < ActiveSupport::TestCase
    test "parses cash location" do
      parsed = AccountReferenceParser.parse("cash:D01")
      assert_equal "cash_location", parsed[:reference_type]
      assert_equal "D01", parsed[:reference_identifier]
    end

    test "parses customer account with acct prefix" do
      parsed = AccountReferenceParser.parse("acct:12345678")
      assert_equal "customer_account", parsed[:reference_type]
      assert_equal "12345678", parsed[:reference_identifier]
    end

    test "parses check clearing" do
      parsed = AccountReferenceParser.parse("check:021:456:789", metadata: { "check_type" => "transit" })
      assert_equal "check_clearing", parsed[:reference_type]
      assert_equal "021", parsed[:check_routing_number]
      assert_equal "456", parsed[:check_account_number]
      assert_equal "789", parsed[:check_number]
      assert_equal "transit", parsed[:check_type]
    end

    test "parses income" do
      parsed = AccountReferenceParser.parse("income:check_cashing_fee")
      assert_equal "income", parsed[:reference_type]
      assert_equal "check_cashing_fee", parsed[:reference_identifier]
    end

    test "parses official_check liability" do
      parsed = AccountReferenceParser.parse("official_check:outstanding")
      assert_equal "liability", parsed[:reference_type]
      assert_equal "outstanding", parsed[:reference_identifier]
    end

    test "parses expense" do
      parsed = AccountReferenceParser.parse("expense:cash_short")
      assert_equal "expense", parsed[:reference_type]
      assert_equal "cash_short", parsed[:reference_identifier]
    end
  end
end
