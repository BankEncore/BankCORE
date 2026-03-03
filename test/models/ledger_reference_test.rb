# frozen_string_literal: true

require "test_helper"

class LedgerReferenceTest < ActiveSupport::TestCase
  setup do
    @branch = Branch.create!(code: "LR", name: "Ledger Ref Branch")
    @account = Account.create!(
      account_number: "1234567890123456",
      account_type: "checking",
      branch: @branch,
      status: "open",
      opened_on: Date.current,
      last_activity_at: Time.current
    )
  end

  test "validates reference presence" do
    lr = LedgerReference.new(ref_type: "customer_account", status: "active")
    refute lr.valid?
    assert_includes lr.errors[:reference], "can't be blank"
  end

  test "validates ref_type inclusion" do
    lr = LedgerReference.new(reference: "acct:test", ref_type: "invalid", status: "active")
    refute lr.valid?
    assert_includes lr.errors[:ref_type], "is not included in the list"
  end

  test "validates reference uniqueness" do
    LedgerReference.create!(reference: "acct:unique", ref_type: "customer_account", status: "active")
    dup = LedgerReference.new(reference: "acct:unique", ref_type: "income_code", status: "active")
    refute dup.valid?
    assert_includes dup.errors[:reference], "has already been taken"
  end

  test "active? returns true for active status" do
    lr = LedgerReference.create!(reference: "income:test_fee", ref_type: "income_code", status: "active")
    assert lr.active?
  end

  test "active? returns false for inactive status" do
    lr = LedgerReference.create!(reference: "income:inactive_fee", ref_type: "income_code", status: "inactive")
    refute lr.active?
  end
end
