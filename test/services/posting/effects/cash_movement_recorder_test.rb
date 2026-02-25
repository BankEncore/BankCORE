require "test_helper"

module Posting
  module Effects
    class CashMovementRecorderTest < ActiveSupport::TestCase
      setup do
        @user = User.take || User.create!(email_address: "cash-effect@example.com", password: "password")
        @branch = Branch.create!(code: "711", name: "Cash Effect Branch")
        @workstation = Workstation.create!(branch: @branch, code: "CE1", name: "Cash Effect WS")
        @drawer = CashLocation.create!(
          branch: @branch,
          code: "CED1",
          name: "Cash Effect Drawer",
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
        @teller_transaction = TellerTransaction.create!(
          user: @user,
          teller_session: @teller_session,
          branch: @branch,
          workstation: @workstation,
          request_id: "ce-tx-1",
          transaction_type: "deposit",
          currency: "USD",
          amount_cents: 10_000,
          status: "posted",
          posted_at: Time.current
        )
      end

      test "records cash in for deposit drawer debit" do
        recorder = CashMovementRecorder.new(
          request: base_request.merge(transaction_type: "deposit"),
          legs: [
            { side: "debit", account_reference: "cash:#{@drawer.code}", amount_cents: 7_000 },
            { side: "credit", account_reference: "acct:deposit", amount_cents: 7_000 }
          ],
          teller_transaction: @teller_transaction
        )

        assert_difference -> { CashMovement.count }, 1 do
          recorder.call
        end

        movement = CashMovement.order(:id).last
        assert_equal "in", movement.direction
        assert_equal 7_000, movement.amount_cents
      end

      test "records cash out for vault transfer drawer credit" do
        recorder = CashMovementRecorder.new(
          request: base_request.merge(transaction_type: "vault_transfer"),
          legs: [
            { side: "debit", account_reference: "cash:V01", amount_cents: 3_000 },
            { side: "credit", account_reference: "cash:#{@drawer.code}", amount_cents: 3_000 }
          ],
          teller_transaction: @teller_transaction
        )

        assert_difference -> { CashMovement.count }, 1 do
          recorder.call
        end

        movement = CashMovement.order(:id).last
        assert_equal "out", movement.direction
        assert_equal 3_000, movement.amount_cents
      end

      test "skips recording when no cash legs are present" do
        recorder = CashMovementRecorder.new(
          request: base_request.merge(transaction_type: "transfer"),
          legs: [
            { side: "debit", account_reference: "acct:from", amount_cents: 4_000 },
            { side: "credit", account_reference: "acct:to", amount_cents: 4_000 }
          ],
          teller_transaction: @teller_transaction
        )

        assert_no_difference -> { CashMovement.count } do
          recorder.call
        end
      end

      test "skips recording for session variance transactions" do
        recorder = CashMovementRecorder.new(
          request: base_request.merge(transaction_type: "session_close_variance"),
          legs: [
            { side: "debit", account_reference: "expense:cash_short", amount_cents: 200 },
            { side: "credit", account_reference: "cash:#{@drawer.code}", amount_cents: 200 }
          ],
          teller_transaction: @teller_transaction
        )

        assert_no_difference -> { CashMovement.count } do
          recorder.call
        end
      end

      test "records cash out for reversal of deposit (inverted from original in)" do
        reversal_tt = TellerTransaction.create!(
          user: @user,
          teller_session: @teller_session,
          branch: @branch,
          workstation: @workstation,
          request_id: "ce-reversal-1",
          transaction_type: "reversal",
          currency: "USD",
          amount_cents: 5_000,
          status: "posted",
          posted_at: Time.current
        )
        request = base_request.merge(
          transaction_type: "reversal",
          metadata: { reversal: { original_transaction_type: "deposit" } }
        )
        recorder = CashMovementRecorder.new(
          request: request,
          legs: [
            { side: "credit", account_reference: "cash:#{@drawer.code}", amount_cents: 5_000 },
            { side: "debit", account_reference: "acct:deposit", amount_cents: 5_000 }
          ],
          teller_transaction: reversal_tt
        )

        assert_difference -> { CashMovement.count }, 1 do
          recorder.call
        end

        movement = CashMovement.order(:id).last
        assert_equal "out", movement.direction
        assert_equal 5_000, movement.amount_cents
      end

      private
        def base_request
          {
            teller_session: @teller_session,
            transaction_type: "deposit"
          }
        end
    end
  end
end
