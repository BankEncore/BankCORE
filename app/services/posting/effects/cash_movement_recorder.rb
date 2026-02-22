module Posting
  module Effects
    class CashMovementRecorder
      def initialize(request:, legs:, teller_transaction:)
        @request = request
        @legs = legs
        @teller_transaction = teller_transaction
      end

      def call
        cash_legs = legs.select { |leg| leg.fetch(:account_reference).start_with?("cash:") }
        return if cash_legs.empty?

        direction = cash_direction(cash_legs)
        return if direction.blank?

        cash_amount_cents = cash_amount(cash_legs, direction)
        return unless cash_amount_cents.positive?

        CashMovement.create!(
          teller_transaction: teller_transaction,
          teller_session: request.fetch(:teller_session),
          cash_location: request.fetch(:teller_session).cash_location,
          direction: direction,
          amount_cents: cash_amount_cents
        )
      end

      private
        attr_reader :request, :legs, :teller_transaction

        def cash_direction(cash_legs)
          case request.fetch(:transaction_type)
          when "deposit", "draft"
            "in"
          when "withdrawal", "check_cashing"
            "out"
          when "vault_transfer"
            vault_transfer_cash_direction(cash_legs)
          end
        end

        def cash_amount(cash_legs, direction)
          case request.fetch(:transaction_type)
          when "deposit", "draft"
            cash_legs.select { |leg| leg.fetch(:side) == "debit" }.sum { |leg| leg.fetch(:amount_cents) }
          when "withdrawal", "check_cashing"
            cash_legs.select { |leg| leg.fetch(:side) == "credit" }.sum { |leg| leg.fetch(:amount_cents) }
          when "vault_transfer"
            vault_transfer_cash_amount(cash_legs, direction)
          else
            0
          end
        end

        def drawer_cash_reference
          drawer_code = request.fetch(:teller_session).cash_location&.code
          return "" if drawer_code.blank?

          "cash:#{drawer_code}"
        end

        def vault_transfer_cash_direction(cash_legs)
          drawer_reference = drawer_cash_reference
          return nil if drawer_reference.blank?

          if cash_legs.any? { |leg| leg.fetch(:side) == "credit" && leg.fetch(:account_reference) == drawer_reference }
            "out"
          elsif cash_legs.any? { |leg| leg.fetch(:side) == "debit" && leg.fetch(:account_reference) == drawer_reference }
            "in"
          end
        end

        def vault_transfer_cash_amount(cash_legs, direction)
          drawer_reference = drawer_cash_reference
          return 0 if drawer_reference.blank?

          if direction == "out"
            cash_legs
              .select { |leg| leg.fetch(:side) == "credit" && leg.fetch(:account_reference) == drawer_reference }
              .sum { |leg| leg.fetch(:amount_cents) }
          elsif direction == "in"
            cash_legs
              .select { |leg| leg.fetch(:side) == "debit" && leg.fetch(:account_reference) == drawer_reference }
              .sum { |leg| leg.fetch(:amount_cents) }
          else
            0
          end
        end
    end
  end
end
