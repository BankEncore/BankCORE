require "test_helper"

module Teller
  class TypedCreatesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = User.take
      @branch = Branch.create!(code: "881", name: "Typed Branch")
      @workstation = Workstation.create!(branch: @branch, code: "TC1", name: "Typed WS")
      @drawer = CashLocation.create!(
        branch: @branch,
        code: "TDR1",
        name: "Typed Drawer",
        location_type: "drawer"
      )
      @vault_a = CashLocation.create!(
        branch: @branch,
        code: "TV1",
        name: "Typed Vault A",
        location_type: "vault"
      )
      @vault_b = CashLocation.create!(
        branch: @branch,
        code: "TV2",
        name: "Typed Vault B",
        location_type: "vault"
      )

      grant_permissions(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
      post teller_teller_session_path, params: { opening_cash_cents: 5_000 }
      patch assign_drawer_teller_teller_session_path, params: { cash_location_id: @drawer.id }
    end

    test "deposit create enforces deposit transaction type" do
      post teller_deposits_path, params: {
        request_id: "typed-dep-1",
        transaction_type: "transfer",
        amount_cents: 12_000,
        primary_account_reference: "acct:dep",
        cash_account_reference: "cash:spoofed"
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-dep-1")
      assert_equal "deposit", transaction.transaction_type
      assert_equal "cash:#{@drawer.code}", transaction.posting_batch.posting_legs.find_by!(side: "debit").account_reference
    end

    test "withdrawal create enforces withdrawal transaction type" do
      post teller_withdrawals_path, params: {
        request_id: "typed-wd-1",
        transaction_type: "deposit",
        amount_cents: 9_000,
        primary_account_reference: "acct:wd",
        cash_account_reference: "cash:spoofed"
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-wd-1")
      assert_equal "withdrawal", transaction.transaction_type
      assert_equal "cash:#{@drawer.code}", transaction.posting_batch.posting_legs.find_by!(side: "credit").account_reference
    end

    test "transfer create enforces transfer transaction type" do
      post teller_transfers_path, params: {
        request_id: "typed-tr-1",
        transaction_type: "deposit",
        amount_cents: 8_000,
        primary_account_reference: "acct:from",
        counterparty_account_reference: "acct:to"
      }

      assert_response :success
      assert_equal "transfer", TellerTransaction.find_by!(request_id: "typed-tr-1").transaction_type
    end

    test "check cashing create enforces check cashing transaction type" do
      post teller_check_cashings_path, params: {
        request_id: "typed-cc-1",
        transaction_type: "deposit",
        amount_cents: 8_000,
        entries: [
          { side: "debit", account_reference: "check:123", amount_cents: 8_000 },
          { side: "credit", account_reference: "cash:#{@drawer.code}", amount_cents: 8_000 }
        ]
      }

      assert_response :success
      assert_equal "check_cashing", TellerTransaction.find_by!(request_id: "typed-cc-1").transaction_type
    end

    test "check cashing create generates fee-aware entries and metadata" do
      post teller_check_cashings_path, params: {
        request_id: "typed-cc-2",
        transaction_type: "check_cashing",
        amount_cents: 9_500,
        check_amount_cents: 10_000,
        fee_cents: 500,
        settlement_account_reference: "acct:check_settlement",
        check_number: "1000123",
        routing_number: "021000021",
        account_number: "123456789",
        payer_name: "Jordan Smith",
        presenter_type: "non_customer",
        id_type: "drivers_license",
        id_number: "D1234567"
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-cc-2")
      assert_equal "check_cashing", transaction.transaction_type
      assert_equal 9_500, transaction.amount_cents

      posting_batch = transaction.posting_batch
      assert_equal 3, posting_batch.posting_legs.count
      assert_equal 9_500, posting_batch.posting_legs.find_by!(side: "credit", account_reference: "cash:#{@drawer.code}").amount_cents
      assert_equal 500, posting_batch.posting_legs.find_by!(side: "credit", account_reference: "income:check_cashing_fee").amount_cents

      metadata = posting_batch.metadata
      assert_equal 10_000, metadata.dig("check_cashing", "check_amount_cents")
      assert_equal 500, metadata.dig("check_cashing", "fee_cents")
      assert_equal 9_500, metadata.dig("check_cashing", "net_cash_payout_cents")
      assert_equal "non_customer", metadata.dig("check_cashing", "presenter_type")
      assert_equal "drivers_license", metadata.dig("check_cashing", "id_type")
    end

    test "draft create enforces draft transaction type" do
      post teller_drafts_path, params: {
        request_id: "typed-dr-1",
        transaction_type: "deposit",
        amount_cents: 8_000,
        draft_funding_source: "account",
        draft_amount_cents: 8_000,
        draft_fee_cents: 0,
        draft_payee_name: "Acme Title",
        draft_instrument_number: "D-1001",
        primary_account_reference: "acct:customer"
      }

      assert_response :success
      assert_equal "draft", TellerTransaction.find_by!(request_id: "typed-dr-1").transaction_type
    end

    test "draft create builds metadata and account-funded entries" do
      post teller_drafts_path, params: {
        request_id: "typed-dr-2",
        transaction_type: "draft",
        amount_cents: 10_250,
        draft_funding_source: "account",
        draft_amount_cents: 10_000,
        draft_fee_cents: 250,
        draft_payee_name: "City Utilities",
        draft_instrument_number: "OD-2001",
        primary_account_reference: "acct:customer",
        draft_liability_account_reference: "official_check:outstanding",
        draft_fee_income_account_reference: "income:draft_fee"
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-dr-2")
      assert_equal "draft", transaction.transaction_type

      posting_batch = transaction.posting_batch
      assert_equal 4, posting_batch.posting_legs.count
      assert_equal 10_000, posting_batch.posting_legs.find_by!(side: "debit", account_reference: "acct:customer").amount_cents
      assert_equal 10_000, posting_batch.posting_legs.find_by!(side: "credit", account_reference: "official_check:outstanding").amount_cents
      assert_equal 250, posting_batch.posting_legs.find_by!(side: "credit", account_reference: "income:draft_fee").amount_cents

      metadata = posting_batch.metadata
      assert_equal "account", metadata.dig("draft", "funding_source")
      assert_equal 10_000, metadata.dig("draft", "draft_amount_cents")
      assert_equal 250, metadata.dig("draft", "fee_cents")
      assert_equal "City Utilities", metadata.dig("draft", "payee_name")
      assert_equal "OD-2001", metadata.dig("draft", "instrument_number")
    end

    test "draft create with cash funding records cash movement in" do
      post teller_drafts_path, params: {
        request_id: "typed-dr-3",
        transaction_type: "draft",
        amount_cents: 5_150,
        draft_funding_source: "cash",
        draft_amount_cents: 5_000,
        draft_fee_cents: 150,
        draft_payee_name: "County Clerk",
        draft_instrument_number: "OD-3001",
        draft_liability_account_reference: "official_check:outstanding",
        draft_fee_income_account_reference: "income:draft_fee"
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-dr-3")
      cash_movement = transaction.cash_movements.last
      assert_not_nil cash_movement
      assert_equal "in", cash_movement.direction
      assert_equal 5_150, cash_movement.amount_cents
    end

    test "vault transfer create enforces vault transfer transaction type" do
      post teller_vault_transfers_path, params: {
        request_id: "typed-vt-1",
        transaction_type: "deposit",
        amount_cents: 7_000,
        vault_transfer_direction: "drawer_to_vault",
        vault_transfer_destination_cash_account_reference: "cash:#{@vault_a.code}",
        vault_transfer_reason_code: "excess_cash",
        vault_transfer_memo: "Cash pull"
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-vt-1")
      assert_equal "vault_transfer", transaction.transaction_type
    end

    test "vault transfer drawer to vault records cash movement out" do
      post teller_vault_transfers_path, params: {
        request_id: "typed-vt-2",
        transaction_type: "vault_transfer",
        amount_cents: 4_000,
        vault_transfer_direction: "drawer_to_vault",
        vault_transfer_destination_cash_account_reference: "cash:#{@vault_a.code}",
        vault_transfer_reason_code: "excess_cash",
        vault_transfer_memo: "Midday rebalance"
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-vt-2")
      posting_batch = transaction.posting_batch
      assert_equal 2, posting_batch.posting_legs.count
      assert_equal 4_000, posting_batch.posting_legs.find_by!(side: "credit", account_reference: "cash:#{@drawer.code}").amount_cents
      assert_equal 4_000, posting_batch.posting_legs.find_by!(side: "debit", account_reference: "cash:#{@vault_a.code}").amount_cents

      cash_movement = transaction.cash_movements.last
      assert_not_nil cash_movement
      assert_equal "out", cash_movement.direction
      assert_equal 4_000, cash_movement.amount_cents
    end

    test "vault transfer vault to vault records no drawer cash movement" do
      post teller_vault_transfers_path, params: {
        request_id: "typed-vt-3",
        transaction_type: "vault_transfer",
        amount_cents: 3_500,
        vault_transfer_direction: "vault_to_vault",
        vault_transfer_source_cash_account_reference: "cash:#{@vault_a.code}",
        vault_transfer_destination_cash_account_reference: "cash:#{@vault_b.code}",
        vault_transfer_reason_code: "end_of_day_adjustment",
        vault_transfer_memo: "Vault balancing"
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-vt-3")
      assert_empty transaction.cash_movements
    end

    private
      def grant_permissions(user, branch, workstation)
        [ "teller.dashboard.view", "transactions.deposit.create", "transactions.check_cashing.create", "transactions.draft.create", "transactions.vault_transfer.create", "sessions.open" ].each do |permission_key|
          permission = Permission.find_or_create_by!(key: permission_key) do |record|
            record.description = permission_key.humanize
          end

          role = Role.find_or_create_by!(key: "teller") do |record|
            record.name = "Teller"
          end

          RolePermission.find_or_create_by!(role: role, permission: permission)
          UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
        end
      end
  end
end
