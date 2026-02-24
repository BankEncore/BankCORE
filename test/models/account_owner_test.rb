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

  test "rejects second primary owner" do
    AccountOwner.create!(account: @account, party: @party1, is_primary: true)
    second_primary = AccountOwner.new(account: @account, party: @party2, is_primary: true)
    assert_not second_primary.valid?
    assert_includes second_primary.errors[:is_primary], "already has a primary owner"
  end
end
