# frozen_string_literal: true

require "test_helper"

class TransactionMiscReceiptDefaultTest < ActiveSupport::TestCase
  setup do
    @type = MiscReceiptType.create!(
      code: "tmrd_test",
      label: "Test Fee",
      income_account_reference: "income:test",
      default_amount_cents: 500,
      memo_required: false,
      display_order: 0,
      is_active: true
    )
  end

  test "validates transaction_type presence" do
    default = TransactionMiscReceiptDefault.new(
      misc_receipt_type: @type,
      transaction_type: "",
      override_policy: "teller_override"
    )
    assert_not default.valid?
    assert_includes default.errors[:transaction_type], "can't be blank"
  end

  test "validates transaction_type inclusion in supported types" do
    default = TransactionMiscReceiptDefault.new(
      misc_receipt_type: @type,
      transaction_type: "unsupported",
      override_policy: "teller_override"
    )
    assert_not default.valid?
    assert_includes default.errors[:transaction_type], "is not included in the list"
  end

  test "validates override_policy inclusion" do
    default = TransactionMiscReceiptDefault.new(
      misc_receipt_type: @type,
      transaction_type: "deposit",
      override_policy: "invalid"
    )
    assert_not default.valid?
    assert_includes default.errors[:override_policy], "is not included in the list"
  end

  test "creates valid record with teller_override" do
    default = TransactionMiscReceiptDefault.create!(
      misc_receipt_type: @type,
      transaction_type: "deposit",
      override_policy: "teller_override",
      display_order: 0
    )
    assert default.teller_override?
    assert_not default.supervisor_override?
    assert_not default.fixed?
  end

  test "creates valid record with supervisor_override" do
    default = TransactionMiscReceiptDefault.create!(
      misc_receipt_type: @type,
      transaction_type: "transfer",
      override_policy: "supervisor_override",
      display_order: 1
    )
    assert default.supervisor_override?
  end

  test "creates valid record with fixed policy" do
    default = TransactionMiscReceiptDefault.create!(
      misc_receipt_type: @type,
      transaction_type: "draft",
      override_policy: "fixed",
      default_amount_cents: 250,
      display_order: 0
    )
    assert default.fixed?
  end

  test "for_transaction_type scope returns matching records" do
    TransactionMiscReceiptDefault.create!(
      misc_receipt_type: @type,
      transaction_type: "deposit",
      override_policy: "teller_override",
      display_order: 0
    )
    other_type = MiscReceiptType.create!(
      code: "tmrd_other",
      label: "Other",
      income_account_reference: "income:other",
      memo_required: false,
      display_order: 1,
      is_active: true
    )
    TransactionMiscReceiptDefault.create!(
      misc_receipt_type: other_type,
      transaction_type: "withdrawal",
      override_policy: "teller_override",
      display_order: 0
    )

    deposit_defaults = TransactionMiscReceiptDefault.for_transaction_type("deposit")
    assert_equal 1, deposit_defaults.count
    assert_equal "deposit", deposit_defaults.first.transaction_type
  end

  test "effective_default_amount_cents uses default when join default is nil" do
    default = TransactionMiscReceiptDefault.create!(
      misc_receipt_type: @type,
      transaction_type: "deposit",
      override_policy: "teller_override",
      default_amount_cents: nil,
      display_order: 0
    )
    assert_equal 500, default.effective_default_amount_cents
  end

  test "effective_default_amount_cents uses join default when present" do
    default = TransactionMiscReceiptDefault.create!(
      misc_receipt_type: @type,
      transaction_type: "deposit",
      override_policy: "teller_override",
      default_amount_cents: 300,
      display_order: 0
    )
    assert_equal 300, default.effective_default_amount_cents
  end
end
