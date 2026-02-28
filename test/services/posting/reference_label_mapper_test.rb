# frozen_string_literal: true

require "test_helper"

module Posting
  class ReferenceLabelMapperTest < ActiveSupport::TestCase
    test "income check_cashing_fee" do
      assert_equal "Check cashing fee",
        ReferenceLabelMapper.label_for({ reference_type: "income", reference_identifier: "check_cashing_fee" })
    end

    test "income transfer_fee" do
      assert_equal "Transfer fee",
        ReferenceLabelMapper.label_for({ reference_type: "income", reference_identifier: "transfer_fee" })
    end

    test "income draft_fee" do
      assert_equal "Draft fee",
        ReferenceLabelMapper.label_for({ reference_type: "income", reference_identifier: "draft_fee" })
    end

    test "income unknown humanizes" do
      assert_equal "Some fee",
        ReferenceLabelMapper.label_for({ reference_type: "income", reference_identifier: "some_fee" })
    end

    test "accepts PostingLeg" do
      leg = PostingLeg.new(
        reference_type: "income",
        reference_identifier: "check_cashing_fee",
        account_reference: "income:check_cashing_fee"
      )
      assert_equal "Check cashing fee", ReferenceLabelMapper.label_for(leg)
    end

    test "nil reference_type falls back to account_reference" do
      assert_equal "income:check_cashing_fee",
        ReferenceLabelMapper.label_for({ account_reference: "income:check_cashing_fee" })
    end

    test "customer_account masks" do
      assert_equal "Account xxxx5678",
        ReferenceLabelMapper.label_for({ reference_type: "customer_account", reference_identifier: "12345678" })
    end

    test "check_clearing with transit" do
      assert_equal "Check (transit)",
        ReferenceLabelMapper.label_for(
          { reference_type: "check_clearing", reference_identifier: "check:021:456:789", check_type: "transit" }
        )
    end

    test "check_clearing with on_us" do
      assert_equal "Check (on us)",
        ReferenceLabelMapper.label_for(
          { reference_type: "check_clearing", reference_identifier: "check:021:456:789", check_type: "on_us" }
        )
    end
  end
end
