# frozen_string_literal: true

require "test_helper"

module Posting
  module Parts
    class PartBuilderTest < ActiveSupport::TestCase
      test "build_entries produces balanced legs for check cashing" do
        legs = PartBuilder.build_entries(
          flow_type: "check_cashing",
          check_items: [ { routing: "021", account: "123", number: "100", account_reference: "check:021:123:100", amount_cents: 10_000 } ],
          fee_cents: 500,
          cash_account_reference: "cash:D01",
          fee_income_account_reference: "income:check_cashing_fee"
        )

        debit_total = legs.select { |l| l[:side] == "debit" }.sum { |l| l[:amount_cents] }
        credit_total = legs.select { |l| l[:side] == "credit" }.sum { |l| l[:amount_cents] }
        assert_equal debit_total, credit_total, "Legs must balance"
      end

      test "check cashing legs have correct check debit, cash credit, fee credit" do
        legs = PartBuilder.build_entries(
          flow_type: "check_cashing",
          check_items: [ { routing: "021", account: "123", number: "100", account_reference: "check:021:123:100", amount_cents: 10_000 } ],
          fee_cents: 500,
          cash_account_reference: "cash:D01",
          fee_income_account_reference: "income:check_cashing_fee"
        )

        check_leg = legs.find { |l| l[:account_reference].start_with?("check:") }
        assert check_leg, "Must have check debit leg"
        assert_equal "debit", check_leg[:side]
        assert_equal 10_000, check_leg[:amount_cents]

        cash_leg = legs.find { |l| l[:account_reference] == "cash:D01" }
        assert cash_leg, "Must have cash credit leg"
        assert_equal "credit", cash_leg[:side]
        assert_equal 9_500, cash_leg[:amount_cents], "Disbursement = CK - FEE = 10000 - 500"

        fee_leg = legs.find { |l| l[:account_reference] == "income:check_cashing_fee" }
        assert fee_leg, "Must have fee credit leg"
        assert_equal "credit", fee_leg[:side]
        assert_equal 500, fee_leg[:amount_cents]
      end

      test "disbursement equals CK minus FEE" do
        legs = PartBuilder.build_entries(
          flow_type: "check_cashing",
          check_items: [ { routing: "021", account: "123", number: "100", account_reference: "check:021:123:100", amount_cents: 25_000 } ],
          fee_cents: 1_250,
          cash_account_reference: "cash:D01"
        )

        cash_leg = legs.find { |l| l[:account_reference] == "cash:D01" }
        assert_equal 23_750, cash_leg[:amount_cents], "25000 - 1250 = 23750"
      end

      test "raises ValidationError when FEE exceeds CK" do
        error = assert_raises(PartBuilder::ValidationError) do
          PartBuilder.build_entries(
            flow_type: "check_cashing",
            check_items: [ { routing: "021", account: "123", number: "100", account_reference: "check:021:123:100", amount_cents: 1_000 } ],
            fee_cents: 1_500,
            cash_account_reference: "cash:D01"
          )
        end
        assert_match /FEE.*exceeds CK/i, error.message
      end

      test "raises ValidationError when check_items empty" do
        error = assert_raises(PartBuilder::ValidationError) do
          PartBuilder.build_entries(
            flow_type: "check_cashing",
            check_items: [],
            fee_cents: 0,
            cash_account_reference: "cash:D01"
          )
        end
        assert_match /empty/i, error.message
      end

      test "raises ValidationError when disbursement not positive" do
        error = assert_raises(PartBuilder::ValidationError) do
          PartBuilder.build_entries(
            flow_type: "check_cashing",
            check_items: [ { routing: "021", account: "123", number: "100", account_reference: "check:021:123:100", amount_cents: 1_000 } ],
            fee_cents: 1_000,
            cash_account_reference: "cash:D01"
          )
        end
        assert_match /Disbursement|positive/i, error.message
      end

      test "legs include position and structured fields" do
        legs = PartBuilder.build_entries(
          flow_type: "check_cashing",
          check_items: [ { routing: "021", account: "123", number: "100", account_reference: "check:021:123:100", amount_cents: 10_000 } ],
          fee_cents: 0,
          cash_account_reference: "cash:D01"
        )

        legs.each_with_index do |leg, i|
          assert_equal i, leg[:position], "Leg at index #{i} must have position #{i}"
        end

        check_leg = legs.find { |l| l[:account_reference].start_with?("check:") }
        assert_equal "check_clearing", check_leg[:reference_type]
        assert_equal "021", check_leg[:check_routing_number]
        assert_equal "123", check_leg[:check_account_number]
        assert_equal "100", check_leg[:check_number]
      end

      test "omits fee leg when fee_cents is zero" do
        legs = PartBuilder.build_entries(
          flow_type: "check_cashing",
          check_items: [ { routing: "021", account: "123", number: "100", account_reference: "check:021:123:100", amount_cents: 10_000 } ],
          fee_cents: 0,
          cash_account_reference: "cash:D01"
        )

        fee_legs = legs.select { |l| l[:account_reference] == "income:check_cashing_fee" }
        assert_equal 0, fee_legs.size, "Should not have fee leg when fee is zero"
      end

      test "multiple checks produce multiple debit legs" do
        legs = PartBuilder.build_entries(
          flow_type: "check_cashing",
          check_items: [
            { routing: "021", account: "111", number: "1", account_reference: "check:021:111:1", amount_cents: 5_000 },
            { routing: "021", account: "222", number: "2", account_reference: "check:021:222:2", amount_cents: 3_000 }
          ],
          fee_cents: 200,
          cash_account_reference: "cash:D01"
        )

        check_legs = legs.select { |l| l[:account_reference].start_with?("check:") }
        assert_equal 2, check_legs.size
        assert_equal [ 5_000, 3_000 ], check_legs.map { |l| l[:amount_cents] }.sort.reverse

        cash_leg = legs.find { |l| l[:account_reference] == "cash:D01" }
        assert_equal 7_800, cash_leg[:amount_cents], "5000 + 3000 - 200"
      end

      test "build_entries for withdrawal returns legs" do
        legs = PartBuilder.build_entries(
          flow_type: "withdrawal",
          amount_cents: 5_000,
          fee_cents: 100,
          primary_account_reference: "acct:123",
          cash_account_reference: "cash:D01"
        )

        assert_equal 3, legs.size
        assert legs.any? { |l| l[:account_reference] == "acct:123" && l[:side] == "debit" }
        assert legs.any? { |l| l[:account_reference] == "cash:D01" && l[:side] == "credit" && l[:amount_cents] == 4_900 }
        assert legs.any? { |l| l[:account_reference]&.start_with?("income:") && l[:amount_cents] == 100 }
      end

      test "build_entries for transfer returns legs" do
        legs = PartBuilder.build_entries(
          flow_type: "transfer",
          amount_cents: 1_000,
          fee_cents: 25,
          primary_account_reference: "acct:123",
          counterparty_account_reference: "acct:456"
        )

        assert_equal 3, legs.size
        assert legs.any? { |l| l[:account_reference] == "acct:123" && l[:side] == "debit" }
        assert legs.any? { |l| l[:account_reference] == "acct:456" && l[:side] == "credit" && l[:amount_cents] == 975 }
        assert legs.any? { |l| l[:account_reference]&.start_with?("income:") && l[:amount_cents] == 25 }
      end

      test "build_entries for deposit returns legs" do
        legs = PartBuilder.build_entries(
          flow_type: "deposit",
          amount_cents: 5_000,
          cash_back_cents: 0,
          fee_cents: 0,
          check_items: [],
          primary_account_reference: "acct:123",
          cash_account_reference: "cash:D01"
        )

        assert legs.any? { |l| l[:account_reference] == "cash:D01" && l[:side] == "debit" && l[:amount_cents] == 5_000 }
        assert legs.any? { |l| l[:account_reference] == "acct:123" && l[:side] == "credit" && l[:amount_cents] == 5_000 }
      end

      test "build_entries for vault_transfer returns legs" do
        legs = PartBuilder.build_entries(
          flow_type: "vault_transfer",
          amount_cents: 10_000,
          source_cash_account_reference: "cash:D01",
          destination_cash_account_reference: "cash:V01"
        )

        assert legs.any? { |l| l[:account_reference] == "cash:V01" && l[:side] == "debit" }
        assert legs.any? { |l| l[:account_reference] == "cash:D01" && l[:side] == "credit" }
      end

      test "raises ArgumentError for unknown flow type" do
        assert_raises(ArgumentError) do
          PartBuilder.build_entries(flow_type: "unknown_flow", amount_cents: 100)
        end
      end

      test "parity with WithdrawalRecipe when FEE is zero" do
        amount = 5_000
        primary = "acct:123"
        cash = "cash:D01"

        recipe_entries = RecipeBuilder.new(
          posting_params: {
            transaction_type: "withdrawal",
            amount_cents: amount,
            primary_account_reference: primary
          },
          default_cash_account_reference: cash
        ).normalized_entries

        part_legs = PartBuilder.build_entries(
          flow_type: "withdrawal",
          amount_cents: amount,
          fee_cents: 0,
          primary_account_reference: primary,
          cash_account_reference: cash
        )

        assert_equal recipe_entries.size, part_legs.size
        recipe_by_key = recipe_entries.index_by { |e| [ e[:side], e[:account_reference], e[:amount_cents] ] }
        part_legs.each do |leg|
          key = [ leg[:side], leg[:account_reference], leg[:amount_cents] ]
          assert recipe_by_key.key?(key), "PartBuilder leg #{leg.inspect} should match RecipeBuilder output"
        end
      end

      test "parity with TransferRecipe when FEE is zero" do
        amount = 1_000
        primary = "acct:123"
        counterparty = "acct:456"

        recipe_entries = RecipeBuilder.new(
          posting_params: {
            transaction_type: "transfer",
            amount_cents: amount,
            fee_cents: 0,
            primary_account_reference: primary,
            counterparty_account_reference: counterparty
          },
          default_cash_account_reference: "cash:D01"
        ).normalized_entries

        part_legs = PartBuilder.build_entries(
          flow_type: "transfer",
          amount_cents: amount,
          fee_cents: 0,
          primary_account_reference: primary,
          counterparty_account_reference: counterparty
        )

        assert_equal recipe_entries.size, part_legs.size
        recipe_by_key = recipe_entries.index_by { |e| [ e[:side], e[:account_reference], e[:amount_cents] ] }
        part_legs.each do |leg|
          key = [ leg[:side], leg[:account_reference], leg[:amount_cents] ]
          assert recipe_by_key.key?(key), "PartBuilder leg #{leg.inspect} should match RecipeBuilder output"
        end
      end

      test "parity with TransferRecipe when FEE is non-zero" do
        amount = 2_000
        fee = 50
        primary = "acct:123"
        counterparty = "acct:456"
        fee_ref = "income:transfer_fee"

        recipe_entries = RecipeBuilder.new(
          posting_params: {
            transaction_type: "transfer",
            amount_cents: amount,
            fee_cents: fee,
            primary_account_reference: primary,
            counterparty_account_reference: counterparty,
            fee_income_account_reference: fee_ref
          },
          default_cash_account_reference: "cash:D01"
        ).normalized_entries

        part_legs = PartBuilder.build_entries(
          flow_type: "transfer",
          amount_cents: amount,
          fee_cents: fee,
          primary_account_reference: primary,
          counterparty_account_reference: counterparty,
          fee_income_account_reference: fee_ref
        )

        assert_equal recipe_entries.size, part_legs.size
        recipe_by_key = recipe_entries.index_by { |e| [ e[:side], e[:account_reference], e[:amount_cents] ] }
        part_legs.each do |leg|
          key = [ leg[:side], leg[:account_reference], leg[:amount_cents] ]
          assert recipe_by_key.key?(key), "PartBuilder leg #{leg.inspect} should match RecipeBuilder output"
        end
      end

      test "parity with DepositRecipe when cash-only (no cash_back, no fee, no checks)" do
        amount = 5_000
        primary = "acct:123"
        cash = "cash:D01"

        recipe_entries = RecipeBuilder.new(
          posting_params: {
            transaction_type: "deposit",
            amount_cents: amount,
            cash_back_cents: 0,
            primary_account_reference: primary
          },
          default_cash_account_reference: cash
        ).normalized_entries

        part_legs = PartBuilder.build_entries(
          flow_type: "deposit",
          amount_cents: amount,
          cash_back_cents: 0,
          fee_cents: 0,
          check_items: [],
          primary_account_reference: primary,
          cash_account_reference: cash
        )

        assert_equal recipe_entries.size, part_legs.size
        recipe_by_key = recipe_entries.index_by { |e| [ e[:side], e[:account_reference], e[:amount_cents] ] }
        part_legs.each do |leg|
          key = [ leg[:side], leg[:account_reference], leg[:amount_cents] ]
          assert recipe_by_key.key?(key), "PartBuilder leg #{leg.inspect} should match RecipeBuilder output"
        end
      end

      test "parity with VaultTransferRecipe when drawer_to_vault" do
        amount = 10_000
        source = "cash:D01"
        dest = "cash:V01"

        recipe_entries = RecipeBuilder.new(
          posting_params: {
            transaction_type: "vault_transfer",
            amount_cents: amount,
            vault_transfer_direction: "drawer_to_vault",
            vault_transfer_destination_cash_account_reference: dest
          },
          default_cash_account_reference: source
        ).normalized_entries

        part_legs = PartBuilder.build_entries(
          flow_type: "vault_transfer",
          amount_cents: amount,
          source_cash_account_reference: source,
          destination_cash_account_reference: dest
        )

        assert_equal recipe_entries.size, part_legs.size
        recipe_by_key = recipe_entries.index_by { |e| [ e[:side], e[:account_reference], e[:amount_cents] ] }
        part_legs.each do |leg|
          key = [ leg[:side], leg[:account_reference], leg[:amount_cents] ]
          assert recipe_by_key.key?(key), "PartBuilder leg #{leg.inspect} should match RecipeBuilder output"
        end
      end

      test "parity with VaultTransferRecipe when vault_to_vault" do
        amount = 5_000
        source = "cash:V01"
        dest = "cash:V02"

        recipe_entries = RecipeBuilder.new(
          posting_params: {
            transaction_type: "vault_transfer",
            amount_cents: amount,
            vault_transfer_direction: "vault_to_vault",
            vault_transfer_source_cash_account_reference: source,
            vault_transfer_destination_cash_account_reference: dest
          },
          default_cash_account_reference: "cash:D01"
        ).normalized_entries

        part_legs = PartBuilder.build_entries(
          flow_type: "vault_transfer",
          amount_cents: amount,
          source_cash_account_reference: source,
          destination_cash_account_reference: dest
        )

        assert_equal recipe_entries.size, part_legs.size
        recipe_by_key = recipe_entries.index_by { |e| [ e[:side], e[:account_reference], e[:amount_cents] ] }
        part_legs.each do |leg|
          key = [ leg[:side], leg[:account_reference], leg[:amount_cents] ]
          assert recipe_by_key.key?(key), "PartBuilder leg #{leg.inspect} should match RecipeBuilder output"
        end
      end

      test "parity with CheckCashingRecipe when FEE is zero" do
        check_items = [
          { routing: "021", account: "123", number: "100", account_reference: "check:021:123:100", amount_cents: 10_000 }
        ]
        cash_ref = "cash:D01"
        fee_ref = "income:check_cashing_fee"
        net_payout = 10_000

        recipe_entries = RecipeBuilder.new(
          posting_params: {
            transaction_type: "check_cashing",
            check_items: check_items,
            fee_cents: 0,
            amount_cents: net_payout
          },
          default_cash_account_reference: cash_ref
        ).normalized_entries

        part_legs = PartBuilder.build_entries(
          flow_type: "check_cashing",
          check_items: check_items,
          fee_cents: 0,
          cash_account_reference: cash_ref,
          fee_income_account_reference: fee_ref
        )

        assert_equal recipe_entries.size, part_legs.size, "Same number of legs"

        recipe_by_key = recipe_entries.index_by { |e| [ e[:side], e[:account_reference], e[:amount_cents] ] }
        part_legs.each do |leg|
          key = [ leg[:side], leg[:account_reference], leg[:amount_cents] ]
          assert recipe_by_key.key?(key), "PartBuilder leg #{leg.inspect} should match RecipeBuilder output"
        end

        part_legs.each do |leg|
          assert leg.key?(:position)
          assert leg.key?(:reference_type) if leg[:account_reference].start_with?("check:")
        end
      end

      test "parity with CheckCashingRecipe when FEE is non-zero" do
        check_items = [
          { routing: "021", account: "123", number: "100", account_reference: "check:021:123:100", amount_cents: 10_000 }
        ]
        cash_ref = "cash:D01"
        fee_ref = "income:check_cashing_fee"
        fee_cents = 500
        net_payout = 10_000 - fee_cents

        recipe_entries = RecipeBuilder.new(
          posting_params: {
            transaction_type: "check_cashing",
            check_items: check_items,
            fee_cents: fee_cents,
            amount_cents: net_payout,
            fee_income_account_reference: fee_ref
          },
          default_cash_account_reference: cash_ref
        ).normalized_entries

        part_legs = PartBuilder.build_entries(
          flow_type: "check_cashing",
          check_items: check_items,
          fee_cents: fee_cents,
          cash_account_reference: cash_ref,
          fee_income_account_reference: fee_ref
        )

        assert_equal recipe_entries.size, part_legs.size, "Same number of legs"

        recipe_by_key = recipe_entries.index_by { |e| [ e[:side], e[:account_reference], e[:amount_cents] ] }
        part_legs.each do |leg|
          key = [ leg[:side], leg[:account_reference], leg[:amount_cents] ]
          assert recipe_by_key.key?(key), "PartBuilder leg #{leg.inspect} should match RecipeBuilder output"
        end
      end
    end
  end
end
