# frozen_string_literal: true

require "test_helper"

module Posting
  module Effects
    class PartyCashDailyTotalUpdaterTest < ActiveSupport::TestCase
      setup do
        @party = Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "CTR Party", is_active: true)
        @party.create_party_individual!(first_name: "CTR", last_name: "Party")
        @user = User.take || User.create!(email_address: "ctr-updater@example.com", password: "password")
        @branch = Branch.create!(code: "811", name: "CTR Branch")
        @workstation = Workstation.create!(branch: @branch, code: "C1", name: "CTR WS")
        @drawer = CashLocation.create!(
          branch: @branch,
          code: "CTD1",
          name: "CTR Drawer",
          location_type: "drawer"
        )
        @teller_session = TellerSession.create!(
          user: @user,
          branch: @branch,
          workstation: @workstation,
          cash_location: @drawer,
          status: "open",
          opened_at: Time.current,
          opening_cash_cents: 10_000
        )
      end

      test "creates PartyCashDailyTotal and increments cash_in_cents for deposit" do
        tt = TellerTransaction.create!(
          user: @user,
          teller_session: @teller_session,
          branch: @branch,
          workstation: @workstation,
          request_id: "ctr-dep-1",
          transaction_type: "deposit",
          currency: "USD",
          amount_cents: 15_000,
          status: "posted",
          posted_at: Time.current
        )
        cm = CashMovement.create!(
          teller_transaction: tt,
          teller_session: @teller_session,
          cash_location: @drawer,
          direction: "in",
          amount_cents: 15_000,
          party_id: @party.id
        )

        assert_difference -> { PartyCashDailyTotal.count }, 1 do
          PartyCashDailyTotalUpdater.call(cash_movement: cm)
        end

        total = PartyCashDailyTotal.find_by(party_id: @party.id, business_date: Date.current)
        assert total.present?
        assert_equal 15_000, total.cash_in_cents
        assert_equal 0, total.cash_out_cents
      end

      test "increments cash_out_cents for withdrawal" do
        tt = TellerTransaction.create!(
          user: @user,
          teller_session: @teller_session,
          branch: @branch,
          workstation: @workstation,
          request_id: "ctr-wd-1",
          transaction_type: "withdrawal",
          currency: "USD",
          amount_cents: 8_000,
          status: "posted",
          posted_at: Time.current
        )
        cm = CashMovement.create!(
          teller_transaction: tt,
          teller_session: @teller_session,
          cash_location: @drawer,
          direction: "out",
          amount_cents: 8_000,
          party_id: @party.id
        )

        PartyCashDailyTotalUpdater.call(cash_movement: cm)

        total = PartyCashDailyTotal.find_by(party_id: @party.id, business_date: Date.current)
        assert_equal 0, total.cash_in_cents
        assert_equal 8_000, total.cash_out_cents
      end

      test "decrements cash_in_cents for reversal of deposit" do
        total = PartyCashDailyTotal.create!(party_id: @party.id, business_date: Date.current, cash_in_cents: 20_000, cash_out_cents: 0)
        original_tt = TellerTransaction.create!(
          user: @user,
          teller_session: @teller_session,
          branch: @branch,
          workstation: @workstation,
          request_id: "ctr-orig-1",
          transaction_type: "deposit",
          currency: "USD",
          amount_cents: 20_000,
          status: "posted",
          posted_at: Time.current
        )
        reversal_tt = TellerTransaction.create!(
          user: @user,
          teller_session: @teller_session,
          branch: @branch,
          workstation: @workstation,
          request_id: "ctr-rev-1",
          transaction_type: "reversal",
          currency: "USD",
          amount_cents: 5_000,
          status: "posted",
          posted_at: Time.current,
          reversal_of_teller_transaction_id: original_tt.id
        )
        cm = CashMovement.create!(
          teller_transaction: reversal_tt,
          teller_session: @teller_session,
          cash_location: @drawer,
          direction: "out",
          amount_cents: 5_000,
          party_id: @party.id
        )

        PartyCashDailyTotalUpdater.call(cash_movement: cm)

        total.reload
        assert_equal 15_000, total.cash_in_cents
        assert_equal 0, total.cash_out_cents
      end

      test "skips update when party_id is nil" do
        tt = TellerTransaction.create!(
          user: @user,
          teller_session: @teller_session,
          branch: @branch,
          workstation: @workstation,
          request_id: "ctr-nil-party",
          transaction_type: "deposit",
          currency: "USD",
          amount_cents: 10_000,
          status: "posted",
          posted_at: Time.current
        )
        cm = CashMovement.create!(
          teller_transaction: tt,
          teller_session: @teller_session,
          cash_location: @drawer,
          direction: "in",
          amount_cents: 10_000,
          party_id: nil
        )

        assert_no_difference -> { PartyCashDailyTotal.count } do
          PartyCashDailyTotalUpdater.call(cash_movement: cm)
        end
      end
    end
  end
end
