# frozen_string_literal: true

require "test_helper"

class PartyCashDailyTotalTest < ActiveSupport::TestCase
  setup do
    @party = Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "CTR Model Party", is_active: true)
    @party.create_party_individual!(first_name: "CTR", last_name: "Model")
  end

  test "parties_exceeding_threshold returns records where total >= threshold" do
    today = Date.current
    over = PartyCashDailyTotal.create!(
      party_id: @party.id,
      business_date: today,
      cash_in_cents: 1_100_000,
      cash_out_cents: 500_000
    )
    other_party = Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Other", is_active: true)
    other_party.create_party_individual!(first_name: "Other", last_name: "Party")
    under = PartyCashDailyTotal.create!(
      party_id: other_party.id,
      business_date: today,
      cash_in_cents: 500_000,
      cash_out_cents: 300_000
    )

    results = PartyCashDailyTotal.parties_exceeding_threshold(date: today, threshold_cents: 1_000_000)

    assert_includes results, over
    assert_not_includes results, under
    assert_equal 1, results.count
  end

  test "parties_exceeding_threshold scopes to given date" do
    today = Date.current
    yesterday = 1.day.ago.to_date
    PartyCashDailyTotal.create!(
      party_id: @party.id,
      business_date: today,
      cash_in_cents: 1_500_000,
      cash_out_cents: 0
    )
    PartyCashDailyTotal.create!(
      party_id: @party.id,
      business_date: yesterday,
      cash_in_cents: 2_000_000,
      cash_out_cents: 0
    )

    results = PartyCashDailyTotal.parties_exceeding_threshold(date: today, threshold_cents: 1_000_000)

    assert_equal 1, results.count
    assert_equal today, results.first.business_date
  end

  test "total_cents returns cash_in plus cash_out" do
    total = PartyCashDailyTotal.new(cash_in_cents: 5_000_000, cash_out_cents: 3_000_000)
    assert_equal 8_000_000, total.total_cents
  end
end
