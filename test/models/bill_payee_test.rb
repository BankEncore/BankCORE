# frozen_string_literal: true

require "test_helper"

class BillPayeeTest < ActiveSupport::TestCase
  test "validates code presence and uniqueness" do
    BillPayee.create!(code: "BP1", name: "Payee 1", liability_account_reference: "liability:BP1", memo_required: false, is_active: true)
    duplicate = BillPayee.new(code: "BP1", name: "Duplicate", liability_account_reference: "liability:dup", memo_required: false, is_active: true)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "validates name and liability_account_reference presence" do
    bp = BillPayee.new(code: "BP2", name: "", liability_account_reference: "", memo_required: false, is_active: true)

    assert_not bp.valid?
    assert_includes bp.errors[:name], "can't be blank"
    assert_includes bp.errors[:liability_account_reference], "can't be blank"
  end

  test "active scope returns only active payees" do
    active = BillPayee.create!(code: "ACTIVE", name: "Active", liability_account_reference: "liability:A", memo_required: false, is_active: true)
    inactive = BillPayee.create!(code: "INACTIVE", name: "Inactive", liability_account_reference: "liability:I", memo_required: false, is_active: false)

    assert_includes BillPayee.active, active
    assert_not_includes BillPayee.active, inactive
  end

  test "ordered scope sorts by display_order and name" do
    BillPayee.create!(code: "Z", name: "Zee", liability_account_reference: "liability:Z", display_order: 1, memo_required: false, is_active: true)
    BillPayee.create!(code: "A", name: "Aye", liability_account_reference: "liability:A", display_order: 0, memo_required: false, is_active: true)

    ordered = BillPayee.ordered.to_a
    assert_equal "A", ordered.first.code
    assert_equal "Z", ordered.last.code
  end
end
