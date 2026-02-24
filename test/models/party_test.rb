# frozen_string_literal: true

require "test_helper"

class PartyTest < ActiveSupport::TestCase
  test "validates party_kind" do
    party = Party.new(relationship_kind: "customer")
    assert_not party.valid?
    assert_includes party.errors[:party_kind], "can't be blank"

    party.party_kind = "invalid"
    assert_not party.valid?
    assert_includes party.errors[:party_kind], "is not included in the list"

    party.party_kind = "individual"
    party.relationship_kind = "customer"
    assert party.valid?
  end

  test "validates relationship_kind" do
    party = Party.new(party_kind: "individual")
    assert_not party.valid?
    assert_includes party.errors[:relationship_kind], "can't be blank"

    party.relationship_kind = "customer"
    assert party.valid?
  end

  test "syncs display_name from party_individual" do
    party = Party.create!(party_kind: "individual", relationship_kind: "customer")
    party.create_party_individual!(first_name: "Jane", last_name: "Doe")
    party.reload
    assert_equal "Jane Doe", party.display_name
  end

  test "syncs display_name from party_organization" do
    party = Party.create!(party_kind: "organization", relationship_kind: "customer")
    party.create_party_organization!(legal_name: "Acme Corp", dba_name: "Acme")
    party.reload
    assert_equal "Acme Corp", party.display_name
  end

  test "encrypts tax_id" do
    party = Party.new(party_kind: "individual", relationship_kind: "customer", tax_id: "12-3456789")
    assert party.tax_id.present?
    assert_equal "12-3456789", party.tax_id
  end
end
