# frozen_string_literal: true

module Posting
  class AccountReferenceParser
    INTERNAL_PREFIXES = %w[cash: check: income: official_check: expense:].freeze

    def self.parse(account_reference, metadata: {})
      new(account_reference, metadata).parse
    end

    def initialize(account_reference, metadata = {})
      @ref = account_reference.to_s.strip
      @metadata = metadata.to_h.transform_keys(&:to_s)
    end

    def parse
      return empty_result if @ref.blank?

      if @ref.start_with?("cash:")
        parse_cash_location
      elsif @ref.start_with?("check:")
        parse_check_clearing
      elsif @ref.start_with?("income:")
        parse_income
      elsif @ref.start_with?("official_check:")
        parse_liability
      elsif @ref.start_with?("expense:")
        parse_expense
      else
        parse_customer_account
      end
    end

    private

    attr_reader :ref, :metadata

    def empty_result
      {
        reference_type: nil,
        reference_identifier: nil,
        check_routing_number: nil,
        check_account_number: nil,
        check_number: nil,
        check_type: nil
      }
    end

    def parse_cash_location
      code = ref.sub(/\Acash:/i, "").strip
      base_result("cash_location", code)
    end

    def parse_customer_account
      identifier = ref.sub(/\Aacct:/, "").strip
      base_result("customer_account", identifier)
    end

    def parse_check_clearing
      parts = ref.sub(/\Acheck:/, "").split(":", 3)
      routing = parts[0].to_s
      account = parts[1].to_s
      number = parts[2].to_s
      check_type = metadata["check_type"].to_s.presence || metadata[:check_type].to_s.presence

      base_result("check_clearing", ref).merge(
        check_routing_number: routing.presence,
        check_account_number: account.presence,
        check_number: number.presence,
        check_type: check_type.presence
      )
    end

    def parse_income
      type = ref.sub(/\Aincome:/, "").strip
      base_result("income", type)
    end

    def parse_liability
      type = ref.sub(/\Aofficial_check:/, "").strip
      base_result("liability", type)
    end

    def parse_expense
      type = ref.sub(/\Aexpense:/, "").strip
      base_result("expense", type)
    end

    def base_result(reference_type, reference_identifier)
      {
        reference_type: reference_type,
        reference_identifier: reference_identifier,
        check_routing_number: nil,
        check_account_number: nil,
        check_number: nil,
        check_type: nil
      }
    end
  end
end
