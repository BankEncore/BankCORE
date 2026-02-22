module Posting
  class PolicyChecker
    CASH_AFFECTING_TRANSACTION_TYPES = %w[deposit withdrawal check_cashing].freeze

    def self.call(request:, error_class: Posting::Engine::Error)
      teller_session = request.fetch(:teller_session)

      raise error_class, "teller session must be open" unless teller_session.open?
      raise error_class, "drawer must be assigned" if drawer_required?(request) && teller_session.cash_location.blank?
    end

    def self.drawer_required?(request)
      return true if CASH_AFFECTING_TRANSACTION_TYPES.include?(request.fetch(:transaction_type))

      cash_legs_include_drawer_reference?(request)
    end

    def self.cash_legs_include_drawer_reference?(request)
      drawer_reference = drawer_cash_reference(request)
      return false if drawer_reference.blank?

      request.fetch(:entries).any? { |entry| entry.fetch(:account_reference) == drawer_reference }
    end

    def self.drawer_cash_reference(request)
      drawer_code = request.fetch(:teller_session).cash_location&.code
      return "" if drawer_code.blank?

      "cash:#{drawer_code}"
    end

    private_class_method :cash_legs_include_drawer_reference?, :drawer_cash_reference
  end
end
