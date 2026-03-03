# frozen_string_literal: true

module Posting
  module Effects
    class PartyCashDailyTotalUpdater
      def self.call(cash_movement:)
        new(cash_movement: cash_movement).call
      end

      def initialize(cash_movement:)
        @cash_movement = cash_movement
      end

      def call
        return if cash_movement.party_id.blank?

        record = find_or_create_record!
        update_totals!(record)
      end

      private
        attr_reader :cash_movement

        def find_or_create_record!
          PartyCashDailyTotal.find_or_create_by!(
            party_id: cash_movement.party_id,
            business_date: business_date
          ) do |r|
            r.cash_in_cents = 0
            r.cash_out_cents = 0
          end
        end

        def business_date
          cash_movement.teller_transaction.posted_at.in_time_zone(Time.zone).to_date
        end

        def update_totals!(record)
          is_reversal = cash_movement.teller_transaction.transaction_type == "reversal"
          amount = cash_movement.amount_cents

          record.with_lock do
            if is_reversal
              # Reversal: subtract from the column the original would have added to
              column = cash_movement.direction == "out" ? :cash_in_cents : :cash_out_cents
              record.decrement!(column, amount)
            else
              column = cash_movement.direction == "in" ? :cash_in_cents : :cash_out_cents
              record.increment!(column, amount)
            end
          end
        end
    end
  end
end
