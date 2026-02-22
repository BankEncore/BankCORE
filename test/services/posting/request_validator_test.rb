require "test_helper"

module Posting
  class RequestValidatorTest < ActiveSupport::TestCase
    class ValidationError < StandardError; end

    test "raises when required key is missing" do
      request = {
        user: Object.new,
        teller_session: Object.new,
        branch: Object.new,
        workstation: Object.new,
        request_id: "req-1",
        transaction_type: "deposit",
        amount_cents: 10_000,
        currency: "USD",
        entries: []
      }

      assert_raises(ValidationError) do
        RequestValidator.call(request: request, error_class: ValidationError)
      end
    end

    test "raises for non-positive amount" do
      request = valid_request.merge(amount_cents: 0)

      error = assert_raises(ValidationError) do
        RequestValidator.call(request: request, error_class: ValidationError)
      end

      assert_equal "amount_cents must be greater than zero", error.message
    end

    test "passes for valid request" do
      assert_nothing_raised do
        RequestValidator.call(request: valid_request, error_class: ValidationError)
      end
    end

    private
      def valid_request
        {
          user: Object.new,
          teller_session: Object.new,
          branch: Object.new,
          workstation: Object.new,
          request_id: "req-1",
          transaction_type: "deposit",
          amount_cents: 10_000,
          currency: "USD",
          entries: [ { side: "debit", account_reference: "cash:D01", amount_cents: 10_000 } ]
        }
      end
  end
end
