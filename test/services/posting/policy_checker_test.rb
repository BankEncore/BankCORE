require "test_helper"

module Posting
  class PolicyCheckerTest < ActiveSupport::TestCase
    class PolicyError < StandardError; end

    SessionStub = Struct.new(:open_state, :cash_location) do
      def open?
        open_state
      end
    end

    CashLocationStub = Struct.new(:code)

    test "raises when teller session is not open" do
      request = base_request.merge(teller_session: SessionStub.new(false, CashLocationStub.new("D01")))

      error = assert_raises(PolicyError) do
        PolicyChecker.call(request: request, error_class: PolicyError)
      end

      assert_equal "teller session must be open", error.message
    end

    test "raises when cash affecting transaction has no drawer" do
      request = base_request.merge(teller_session: SessionStub.new(true, nil), transaction_type: "deposit")

      error = assert_raises(PolicyError) do
        PolicyChecker.call(request: request, error_class: PolicyError)
      end

      assert_equal "drawer must be assigned", error.message
    end

    test "allows non cash transaction without drawer" do
      request = base_request.merge(
        teller_session: SessionStub.new(true, nil),
        transaction_type: "transfer",
        entries: [
          { side: "debit", account_reference: "acct:from", amount_cents: 1000 },
          { side: "credit", account_reference: "acct:to", amount_cents: 1000 }
        ]
      )

      assert_nothing_raised do
        PolicyChecker.call(request: request, error_class: PolicyError)
      end
    end

    private
      def base_request
        {
          teller_session: SessionStub.new(true, CashLocationStub.new("D01")),
          transaction_type: "deposit",
          entries: [
            { side: "debit", account_reference: "cash:D01", amount_cents: 1000 },
            { side: "credit", account_reference: "acct:dep", amount_cents: 1000 }
          ]
        }
      end
  end
end
