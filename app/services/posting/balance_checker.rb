module Posting
  class BalanceChecker
    def self.call(legs:, error_class: Posting::Engine::Error)
      debit_total = legs.select { |leg| leg[:side] == "debit" }.sum { |leg| leg[:amount_cents] }
      credit_total = legs.select { |leg| leg[:side] == "credit" }.sum { |leg| leg[:amount_cents] }

      raise error_class, "posting legs are unbalanced" unless debit_total == credit_total
    end
  end
end
