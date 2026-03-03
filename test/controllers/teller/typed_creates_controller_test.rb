require "test_helper"

module Teller
  class TypedCreatesControllerTest < ActionDispatch::IntegrationTest
    setup do
      ensure_cash_denominations
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

      %w[dep wd from to customer BP_TYPED].each do |acct_num|
        next if Account.exists?(account_number: acct_num)

        Account.create!(
          account_number: acct_num,
          account_type: "checking",
          branch: @branch,
          status: "open",
          opened_on: Date.current,
          last_activity_at: Time.current
        )
      end

      grant_permissions(@user, @branch, @workstation)
      sign_in_as(@user)
      patch teller_context_path, params: { branch_id: @branch.id, workstation_id: @workstation.id }
      post teller_teller_session_path, params: { opening_cash_cents: 5_000, cash_location_id: @drawer.id }
      @party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Typed Test Party", is_active: true)
    end

    test "deposit create enforces deposit transaction type" do
      post teller_deposits_path, params: {
        request_id: "typed-dep-1",
        transaction_type: "transfer",
        amount_cents: 12_000,
        party_id: @party.id,
        primary_account_reference: "acct:dep",
        cash_account_reference: "cash:spoofed"
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-dep-1")
      assert_equal "deposit", transaction.transaction_type
      assert_equal "cash:#{@drawer.code}", transaction.posting_batch.posting_legs.find_by!(side: "debit").account_reference
    end

    test "deposit create with cash_back stores metadata" do
      post teller_deposits_path, params: {
        request_id: "typed-dep-cb-1",
        transaction_type: "deposit",
        amount_cents: 8_000,
        party_id: @party.id,
        primary_account_reference: "acct:dep",
        cash_account_reference: "cash:#{@drawer.code}",
        cash_back_cents: 2_000,
        entries: [
          { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 10_000 },
          { side: "credit", account_reference: "cash:#{@drawer.code}", amount_cents: 2_000 },
          { side: "credit", account_reference: "acct:dep", amount_cents: 8_000 }
        ]
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-dep-cb-1")
      assert_equal "deposit", transaction.transaction_type
      assert_equal 8_000, transaction.amount_cents
      assert_equal 2_000, transaction.posting_batch.metadata["cash_back_cents"]
    end

    test "withdrawal create enforces withdrawal transaction type" do
      post teller_withdrawals_path, params: {
        request_id: "typed-wd-1",
        transaction_type: "deposit",
        amount_cents: 9_000,
        party_id: @party.id,
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
        party_id: @party.id,
        primary_account_reference: "acct:from",
        counterparty_account_reference: "acct:to"
      }

      assert_response :success
      assert_equal "transfer", TellerTransaction.find_by!(request_id: "typed-tr-1").transaction_type
    end

    test "check cashing create enforces check_cashing transaction type" do
      party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Test Party", is_active: true)
      post teller_check_cashings_path, params: {
        request_id: "typed-cc-1",
        transaction_type: "deposit",
        amount_cents: 8_000,
        party_id: party.id,
        check_items: [ { routing: "021000021", account: "123456789", number: "1001", account_reference: "check:021000021:123456789:1001", amount_cents: 8_000 } ],
        entries: [
          { side: "debit", account_reference: "check:021000021:123456789:1001", amount_cents: 8_000 },
          { side: "credit", account_reference: "cash:#{@drawer.code}", amount_cents: 8_000 }
        ]
      }

      assert_response :success
      assert_equal "check_cashing", TellerTransaction.find_by!(request_id: "typed-cc-1").transaction_type
    end

    test "check cashing create generates fee-aware entries and metadata" do
      party = Party.where(party_kind: "individual").first || Party.create!(party_kind: "individual", relationship_kind: "customer", display_name: "Jordan Smith", is_active: true)
      post teller_check_cashings_path, params: {
        request_id: "typed-cc-2",
        transaction_type: "check_cashing",
        amount_cents: 9_500,
        party_id: party.id,
        fee_cents: 500,
        check_items: [ { routing: "021000021", account: "123456789", number: "1000123", account_reference: "check:021000021:123456789:1000123", amount_cents: 10_000 } ],
        entries: [
          { side: "debit", account_reference: "check:021000021:123456789:1000123", amount_cents: 10_000 },
          { side: "credit", account_reference: "cash:#{@drawer.code}", amount_cents: 9_500 },
          { side: "credit", account_reference: "income:check_cashing_fee", amount_cents: 500 }
        ]
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
      assert_equal party.id.to_s, metadata.dig("check_cashing", "party_id")
    end

    test "draft create enforces draft transaction type" do
      post teller_drafts_path, params: {
        request_id: "typed-dr-1",
        transaction_type: "deposit",
        amount_cents: 8_000,
        party_id: @party.id,
        draft_amount_cents: 8_000,
        draft_fee_cents: 0,
        draft_cash_cents: 0,
        draft_account_cents: 8_000,
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
        party_id: @party.id,
        draft_amount_cents: 10_000,
        draft_fee_cents: 250,
        draft_cash_cents: 0,
        draft_account_cents: 10_250,
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
      assert_equal 3, posting_batch.posting_legs.count
      assert_equal 10_250, posting_batch.posting_legs.find_by!(side: "debit", account_reference: "acct:customer").amount_cents
      assert_equal 10_000, posting_batch.posting_legs.find_by!(side: "credit", account_reference: "official_check:outstanding").amount_cents
      assert_equal 250, posting_batch.posting_legs.find_by!(side: "credit", account_reference: "income:draft_fee").amount_cents

      metadata = posting_batch.metadata
      assert_equal 0, metadata.dig("draft", "draft_cash_cents")
      assert_equal 10_250, metadata.dig("draft", "draft_account_cents")
      assert_equal 10_000, metadata.dig("draft", "draft_amount_cents")
      assert_equal 250, metadata.dig("draft", "fee_cents")
      assert_equal "City Utilities", metadata.dig("draft", "payee_name")
      assert_equal "OD-2001", metadata.dig("draft", "instrument_number")
    end

    test "bill_payment create posts balanced legs and stores metadata" do
      payee = BillPayee.create!(code: "BP_TYPED", name: "Typed Payee", liability_account_reference: "liability:BP_TYPED", memo_required: false, is_active: true)

      post teller_bill_payments_path, params: {
        request_id: "typed-bp-1",
        transaction_type: "bill_payment",
        amount_cents: 10_000,
        party_id: @party.id,
        payee_id: payee.id,
        payee_reference: "REF001",
        payment_cents: 10_000,
        fee_cents: 0,
        bill_payment_cash_cents: 10_000,
        bill_payment_account_cents: 0,
        cash_account_reference: "cash:#{@drawer.code}",
        liability_account_reference: payee.liability_account_reference
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-bp-1")
      assert_equal "bill_payment", transaction.transaction_type
      assert_equal 10_000, transaction.amount_cents

      posting_batch = transaction.posting_batch
      assert_equal 2, posting_batch.posting_legs.count
      assert_equal 10_000, posting_batch.posting_legs.find_by!(side: "debit", account_reference: "cash:#{@drawer.code}").amount_cents
      assert_equal 10_000, posting_batch.posting_legs.find_by!(side: "credit", account_reference: "liability:BP_TYPED").amount_cents

      metadata = posting_batch.metadata
      assert_equal payee.id.to_s, metadata.dig("bill_payment", "payee_id")
      assert_equal "BP_TYPED", metadata.dig("bill_payment", "payee_code")
      assert_equal 10_000, metadata.dig("bill_payment", "payment_cents")
      assert_equal 0, metadata.dig("bill_payment", "fee_cents")
    end

    test "draft create with cash funding records cash movement in" do
      post teller_drafts_path, params: {
        request_id: "typed-dr-3",
        transaction_type: "draft",
        amount_cents: 5_150,
        party_id: @party.id,
        draft_amount_cents: 5_000,
        draft_fee_cents: 150,
        draft_cash_cents: 5_150,
        draft_account_cents: 0,
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
        vault_transfer_memo: "Cash pull",
        denomination_lines: denomination_lines_for(7_000)
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
        vault_transfer_memo: "Midday rebalance",
        denomination_lines: denomination_lines_for(4_000)
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
        vault_transfer_memo: "Vault balancing",
        denomination_lines: denomination_lines_for(3_500)
      }

      assert_response :success
      transaction = TellerTransaction.find_by!(request_id: "typed-vt-3")
      assert_empty transaction.cash_movements
    end

    test "vault transfer create returns validation error when reason is missing" do
      post teller_vault_transfers_path, params: {
        request_id: "typed-vt-4",
        transaction_type: "vault_transfer",
        amount_cents: 4_000,
        vault_transfer_direction: "drawer_to_vault",
        vault_transfer_destination_cash_account_reference: "cash:#{@vault_a.code}",
        vault_transfer_reason_code: ""
      }

      assert_response :unprocessable_entity
      body = JSON.parse(response.body)
      assert_equal false, body["ok"]
      assert_equal "Reason code is required", body["error"]
    end

    test "typed new transaction pages render without cash location errors" do
      get new_teller_deposit_path
      assert_response :success
      assert_select "section[data-deposit-form-target='checkSection']:not([hidden])", count: 1

      [
        new_teller_withdrawal_path,
        new_teller_transfer_path,
        new_teller_check_cashing_path,
        new_teller_draft_path,
        new_teller_bill_payment_path,
        new_teller_vault_transfer_path
      ].each do |path|
        get path
        assert_response :success
      end
    end

    private
      def ensure_cash_denominations
        return if CashDenomination.enabled.exists?

        CashDenomination.create!(
          code: "USD_BILL_20",
          kind: "bill",
          face_value_cents: 2_000,
          display_label: "$20",
          sort_order: 50,
          enabled: true
        )
        CashDenomination.create!(
          code: "USD_BILL_10",
          kind: "bill",
          face_value_cents: 1_000,
          display_label: "$10",
          sort_order: 40,
          enabled: true
        )
        CashDenomination.create!(
          code: "USD_BILL_5",
          kind: "bill",
          face_value_cents: 500,
          display_label: "$5",
          sort_order: 30,
          enabled: true
        )
      end

      def denomination_lines_for(amount_cents)
        denom = CashDenomination.enabled.to_a.find { |d| amount_cents % d.unit_value_cents == 0 }
        return [] if denom.blank?

        qty = amount_cents / denom.unit_value_cents
        [
          { cash_denomination_id: denom.id, qty: qty, amount_cents: amount_cents }
        ]
      end

      def grant_permissions(user, branch, workstation)
        [ "teller.dashboard.view", "transactions.deposit.create", "transactions.check_cashing.create", "transactions.draft.create", "transactions.bill_payment.create", "transactions.vault_transfer.create", "sessions.open" ].each do |permission_key|
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
