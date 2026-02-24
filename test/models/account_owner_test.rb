# frozen_string_literal: true

require "test_helper"

class AccountOwnerTest < ActiveSupport::TestCase
  setup do
    @branch = Branch.first || Branch.create!(code: "001", name: "Main")
    @party1 = Party.create!(party_kind: "individual", relationship_kind: "customer")
    @party1.create_party_individual!(first_name: "A", last_name: "One")
    @party2 = Party.create!(party_kind: "individual", relationship_kind: "customer")
    @party2.create_party_individual!(first_name: "B", last_name: "Two")
    @account = Account.create!(account_number: "1234567890123456", account_type: "checking", branch: @branch, status: "open", opened_on: Date.current, last_activity_at: Time.current)
  end

  test "allows one primary owner per account" do
    AccountOwner.create!(account: @account, party: @party1, is_primary: true)
    assert AccountOwner.new(account: @account, party: @party2, is_primary: false).valid?
  end

  test "setting new primary demotes existing primary" do
    ao1 = AccountOwner.create!(account: @account, party: @party1, is_primary: true)
    ao2 = AccountOwner.create!(account: @account, party: @party2, is_primary: false)
    ao2.update!(is_primary: true)
    assert ao2.reload.is_primary?
    assert_not ao1.reload.is_primary?
  end

  test "prevents removing last owner" do
    ao = AccountOwner.create!(account: @account, party: @party1, is_primary: true)
    assert_no_difference "AccountOwner.count" do
      ao.destroy
    end
    assert_includes ao.errors[:base], "Account must have at least one owner"
  end

  test "allows removing owner when others remain" do
    AccountOwner.create!(account: @account, party: @party1, is_primary: true)
    ao2 = AccountOwner.create!(account: @account, party: @party2, is_primary: false)
    assert_difference "AccountOwner.count", -1 do
      ao2.destroy
    end
  end
end
