module Posting
  class RequestValidator
    REQUIRED_KEYS = %i[user teller_session branch workstation request_id transaction_type amount_cents currency entries].freeze

    def self.call(request:, error_class: Posting::Engine::Error)
      REQUIRED_KEYS.each do |key|
        value = request[key]
        raise error_class, "#{key} is required" if value.blank?
      end

      raise error_class, "amount_cents must be greater than zero" unless request[:amount_cents].positive?
      raise error_class, "entries must be present" if request[:entries].empty?
    end
  end
end
