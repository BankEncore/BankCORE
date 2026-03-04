# frozen_string_literal: true

require "test_helper"

module Posting
  module Parts
    module Flows
      class VaultTransferFlowTest < ActiveSupport::TestCase
        test "produces balanced legs" do
          flow = VaultTransferFlow.new(
            amount_cents: 10_000,
            source_cash_account_reference: "cash:D01",
            destination_cash_account_reference: "cash:V01"
          )

          legs = flow.build_entries
          debit_total = legs.select { |l| l[:side] == "debit" }.sum { |l| l[:amount_cents] }
          credit_total = legs.select { |l| l[:side] == "credit" }.sum { |l| l[:amount_cents] }
          assert_equal debit_total, credit_total
        end

        test "debit destination, credit source" do
          flow = VaultTransferFlow.new(
            amount_cents: 5_000,
            source_cash_account_reference: "cash:D01",
            destination_cash_account_reference: "cash:V01"
          )

          legs = flow.build_entries

          debit_leg = legs.find { |l| l[:side] == "debit" }
          assert_equal "cash:V01", debit_leg[:account_reference]
          assert_equal 5_000, debit_leg[:amount_cents]

          credit_leg = legs.find { |l| l[:side] == "credit" }
          assert_equal "cash:D01", credit_leg[:account_reference]
          assert_equal 5_000, credit_leg[:amount_cents]
        end

        test "raises when amount_cents <= 0" do
          flow = VaultTransferFlow.new(
            amount_cents: 0,
            source_cash_account_reference: "cash:D01",
            destination_cash_account_reference: "cash:V01"
          )

          assert_raises(PartBuilder::ValidationError) { flow.build_entries }
        end

        test "raises when source equals destination" do
          flow = VaultTransferFlow.new(
            amount_cents: 1_000,
            source_cash_account_reference: "cash:D01",
            destination_cash_account_reference: "cash:D01"
          )

          error = assert_raises(PartBuilder::ValidationError) { flow.build_entries }
          assert_match /same|Source and destination/i, error.message
        end
      end
    end
  end
end
