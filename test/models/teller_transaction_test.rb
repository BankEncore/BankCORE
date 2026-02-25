require "test_helper"

class TellerTransactionTest < ActiveSupport::TestCase
  setup do
    @user = User.take || User.create!(email_address: "reversal-test@example.com", password: "password")
    @branch = Branch.take || Branch.create!(code: "999", name: "Test Branch")
    @workstation = Workstation.create!(branch: @branch, code: "R99", name: "Reversal WS")
    @drawer = CashLocation.create!(
      branch: @branch,
      code: "RD99",
      name: "Reversal Drawer",
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

  test "reversible? returns true for deposit" do
    tx = create_posted_transaction("deposit")
    assert tx.reversible?
  end

  test "reversible? returns false for session_close_variance" do
    tx = create_posted_transaction("session_close_variance")
    refute tx.reversible?
  end

  test "reversible? returns false for reversal" do
    tx = create_posted_transaction("reversal")
    refute tx.reversible?
  end

  test "reversible? returns false when already reversed" do
    tx = create_posted_transaction("deposit")
    assert tx.reversible?
    reversal_tx = create_posted_transaction("reversal")
    tx.update!(reversed_by_teller_transaction_id: reversal_tx.id)
    tx.reload
    refute tx.reversible?
  end

  test "reversed? returns true when reversed_by_teller_transaction_id present" do
    tx = create_posted_transaction("deposit")
    refute tx.reversed?
    reversal_tx = create_posted_transaction("reversal")
    tx.update!(reversed_by_teller_transaction_id: reversal_tx.id)
    tx.reload
    assert tx.reversed?
  end

  private

  def create_posted_transaction(transaction_type)
    TellerTransaction.create!(
      user: @user,
      teller_session: @teller_session,
      branch: @branch,
      workstation: @workstation,
      request_id: "test-#{transaction_type}-#{SecureRandom.hex(4)}",
      transaction_type: transaction_type,
      amount_cents: 10_000,
      currency: "USD",
      status: "posted",
      posted_at: Time.current
    )
  end
end
