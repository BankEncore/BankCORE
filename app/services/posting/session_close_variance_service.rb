module Posting
  class SessionCloseVarianceService
    def initialize(teller_session:, declared_cents:, expected_cents:, variance_reason: nil, variance_notes: nil)
      @teller_session = teller_session
      @declared_cents = declared_cents.to_i
      @expected_cents = expected_cents.to_i
      @variance_reason = variance_reason
      @variance_notes = variance_notes
    end

    def call
      variance_cents = @declared_cents - @expected_cents
      return if variance_cents.zero?
      return if @teller_session.cash_location.blank?

      amount_cents = variance_cents.abs
      drawer_reference = "cash:#{@teller_session.cash_location.code}"

      legs = if variance_cents.negative?
        [
          { side: "debit", account_reference: "expense:cash_short", amount_cents: amount_cents },
          { side: "credit", account_reference: drawer_reference, amount_cents: amount_cents }
        ]
      else
        [
          { side: "debit", account_reference: drawer_reference, amount_cents: amount_cents },
          { side: "credit", account_reference: "income:cash_over", amount_cents: amount_cents }
        ]
      end

      request = {
        user: @teller_session.user,
        teller_session: @teller_session,
        branch: @teller_session.branch,
        workstation: @teller_session.workstation,
        request_id: "session-close-#{@teller_session.id}",
        transaction_type: "session_close_variance",
        amount_cents: amount_cents,
        entries: legs.map.with_index { |leg, i| leg.merge(position: i) },
        metadata: {
          variance_reason: @variance_reason,
          variance_notes: @variance_notes,
          declared_cents: @declared_cents,
          expected_cents: @expected_cents
        },
        currency: "USD"
      }

      Posting::Engine.new(
        user: request[:user],
        teller_session: request[:teller_session],
        branch: request[:branch],
        workstation: request[:workstation],
        request_id: request[:request_id],
        transaction_type: request[:transaction_type],
        amount_cents: request[:amount_cents],
        entries: legs,
        metadata: request[:metadata],
        currency: request[:currency]
      ).call
    end
  end
end
