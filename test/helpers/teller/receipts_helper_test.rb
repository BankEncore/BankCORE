# frozen_string_literal: true

require "test_helper"

module Teller
  module ReceiptsHelper
    class CheckHoldIndicatorTest < ActiveSupport::TestCase
      include Teller::ReceiptsHelper

      test "returns T for transit without hold" do
        assert_equal "T", check_hold_indicator({ "check_type" => "transit" })
        assert_equal "T", check_hold_indicator({ check_type: "transit" })
      end

      test "returns O for on_us without hold" do
        assert_equal "O", check_hold_indicator({ "check_type" => "on_us" })
        assert_equal "O", check_hold_indicator({ check_type: "on_us" })
      end

      test "returns T* for transit with hold" do
        assert_equal "T*", check_hold_indicator({ "check_type" => "transit", "hold_reason" => "large_item" })
      end

      test "returns O* for on_us with hold" do
        assert_equal "O*", check_hold_indicator({ "check_type" => "on_us", "hold_reason" => "new_account" })
      end

      test "defaults to T when check_type blank" do
        assert_equal "T", check_hold_indicator({})
        assert_equal "T", check_hold_indicator({ "check_type" => "" })
      end
    end

    class DepositAvailabilityRowsTest < ActiveSupport::TestCase
      include Teller::ReceiptsHelper

      def posting_batch(committed_at: Date.current)
        PostingBatch.new(committed_at: committed_at)
      end

      test "returns immediate row for cash only" do
        rows = deposit_availability_rows(posting_batch, 10_000, [])
        assert_equal 1, rows.size
        assert_equal "Immediate", rows[0][:label]
        assert_equal 10_000, rows[0][:amount_cents]
      end

      test "deducts cash back from immediate first" do
        rows = deposit_availability_rows(posting_batch, 10_000, [], cash_back_cents: 3_000)
        assert_equal 1, rows.size
        assert_equal "Immediate", rows[0][:label]
        assert_equal 7_000, rows[0][:amount_cents]
      end

      test "deducts cash back from immediate then non-held checks" do
        check_items = [
          { "amount_cents" => 30_000, "hold_reason" => "", "hold_until" => "" }
        ]
        rows = deposit_availability_rows(posting_batch, 5_000, check_items, cash_back_cents: 10_000)
        immediate = rows.find { |r| r[:label] == "Immediate" }
        assert_nil immediate, "Immediate (5k) should be fully consumed by cash back"
        next_day = rows.find { |r| r[:amount_cents] == 20_000 }
        assert next_day, "Next day first 250: 25k - 5k consumed = 20k"
      end

      test "deducts cash back from held checks last" do
        check_items = [
          { "amount_cents" => 10_000, "hold_reason" => "large", "hold_until" => "2026-03-15" }
        ]
        rows = deposit_availability_rows(posting_batch, 5_000, check_items, cash_back_cents: 12_000)
        immediate = rows.find { |r| r[:label] == "Immediate" }
        assert_nil immediate
        held_row = rows.find { |r| r[:label].include?("March") }
        assert held_row, "Should have held row"
        assert_equal 3_000, held_row[:amount_cents], "Held 10k minus 7k consumed (5k immediate + 2k from next-day 250)"
      end

      test "returns empty when cash back consumes all" do
        rows = deposit_availability_rows(posting_batch, 5_000, [], cash_back_cents: 5_000)
        assert_empty rows
      end
    end
  end
end
