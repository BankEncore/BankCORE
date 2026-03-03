# frozen_string_literal: true

require "test_helper"

module LedgerReferences
  class ResolverTest < ActiveSupport::TestCase
    setup do
      @branch = Branch.create!(code: "RS", name: "Resolver Branch")
      @account = Account.create!(
        account_number: "9999888877776666",
        account_type: "checking",
        branch: @branch,
        status: "open",
        opened_on: Date.current,
        last_activity_at: Time.current
      )
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "RSD1",
        name: "Resolver Drawer",
        location_type: "drawer"
      )
    end

    test "resolves acct: prefixed customer account" do
      resolved = Resolver.call(reference: "acct:#{@account.account_number}")
      assert resolved.present?
      assert_equal "customer_account", resolved.ref_type
      assert_equal @account.id, resolved.account_id
    end

    test "resolves bare account number by normalizing to acct:" do
      resolved = Resolver.call(reference: @account.account_number)
      assert resolved.present?
      assert_equal "customer_account", resolved.ref_type
    end

    test "resolves cash location" do
      resolved = Resolver.call(reference: "cash:#{@drawer.code}")
      assert resolved.present?
      assert_equal "cash_location", resolved.ref_type
      assert_equal @drawer.id, resolved.cash_location_id
    end

    test "resolves income code" do
      LedgerReference.find_or_create_by!(reference: "income:check_cashing_fee") do |lr|
        lr.ref_type = "income_code"
        lr.status = "active"
      end
      resolved = Resolver.call(reference: "income:check_cashing_fee")
      assert resolved.present?
      assert_equal "income_code", resolved.ref_type
    end

    test "lazy-registers check clearing reference" do
      ref = "check:021:123456:789"
      resolved = Resolver.call(reference: ref)
      assert resolved.present?
      assert_equal "check_clearing", resolved.ref_type
      assert_equal ref, resolved.reference
    end

    test "raises UnresolvedReference for unknown reference" do
      assert_raises(Resolver::UnresolvedReference) do
        Resolver.call(reference: "acct:nonexistent12345")
      end
    end

    test "raises UnresolvedReference for blank reference" do
      assert_raises(Resolver::UnresolvedReference) do
        Resolver.call(reference: "")
      end
    end
  end
end
