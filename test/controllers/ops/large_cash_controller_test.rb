# frozen_string_literal: true

require "test_helper"

module Ops
  class LargeCashControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      sign_in_as(@user)
      @party = Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Large Cash Party", is_active: true)
      @party.create_party_individual!(first_name: "Large", last_name: "Cash")
    end

    test "index requires authentication" do
      sign_out
      get ops_large_cash_path
      assert_redirected_to new_session_path
    end

    test "index shows report with no records by default" do
      get ops_large_cash_path

      assert_response :success
      assert_select "h2", "Large Cash Transactions"
      assert_select "table"
      assert_select "td", "No records for this date and filter."
    end

    test "index shows parties exceeding threshold when filtered by date" do
      today = Date.current
      PartyCashDailyTotal.create!(
        party_id: @party.id,
        business_date: today,
        cash_in_cents: 1_500_000,
        cash_out_cents: 500_000
      )

      get ops_large_cash_path, params: { date: today }

      assert_response :success
      assert_select "h2", "Large Cash Transactions"
      assert_select "table tbody tr", count: 1
      assert_select "td", "Large Cash"
      assert_select "td", "$20,000.00"
      assert_select "span.badge-warning", "Yes"
    end

    test "index filters by party when party_id provided" do
      today = Date.current
      other_party = Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Other", is_active: true)
      other_party.create_party_individual!(first_name: "Other", last_name: "Party")
      PartyCashDailyTotal.create!(
        party_id: @party.id,
        business_date: today,
        cash_in_cents: 1_500_000,
        cash_out_cents: 0
      )
      PartyCashDailyTotal.create!(
        party_id: other_party.id,
        business_date: today,
        cash_in_cents: 500_000,
        cash_out_cents: 0
      )

      get ops_large_cash_path, params: { date: today, party_id: other_party.id }

      assert_response :success
      assert_select "table tbody tr", count: 1
      assert_select "td", "Other Party"
      assert_select "span.badge-ghost", "No"
    end

    test "index respects custom threshold" do
      today = Date.current
      PartyCashDailyTotal.create!(
        party_id: @party.id,
        business_date: today,
        cash_in_cents: 600_000,
        cash_out_cents: 0
      )

      get ops_large_cash_path, params: { date: today, threshold: 5_000 }

      assert_response :success
      assert_select "table tbody tr", count: 1
      assert_select "td", "Large Cash"
    end

    test "index excludes parties under threshold when no party filter" do
      today = Date.current
      PartyCashDailyTotal.create!(
        party_id: @party.id,
        business_date: today,
        cash_in_cents: 500_000,
        cash_out_cents: 300_000
      )

      get ops_large_cash_path, params: { date: today }

      assert_response :success
      assert_select "td", "No records for this date and filter."
    end
  end
end
