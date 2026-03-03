# frozen_string_literal: true

module LedgerReferences
  class Resolver
    class UnresolvedReference < StandardError
      attr_reader :reference

      def initialize(reference)
        @reference = reference
        super("Unknown account reference: #{reference.inspect}")
      end
    end

    INTERNAL_PREFIXES = %w[cash: check: income: official_check: expense: liability:].freeze

    def self.call(reference:)
      new(reference: reference).call
    end

    def initialize(reference:)
      @reference = reference.to_s.strip
    end

    def call
      raise UnresolvedReference, @reference if @reference.blank?

      canonical = normalize_reference
      resolved = find_or_lazy_create(canonical)
      raise UnresolvedReference, @reference if resolved.nil?
      raise UnresolvedReference, @reference unless resolved.active?

      resolved
    end

    private

    def normalize_reference
      return @reference if @reference.blank?
      return @reference if INTERNAL_PREFIXES.any? { |p| @reference.start_with?(p) }
      return @reference if @reference.start_with?("acct:")

      "acct:#{@reference}"
    end

    def find_or_lazy_create(canonical)
      if canonical.start_with?("check:")
        LedgerReference.find_or_create_by!(reference: canonical) do |lr|
          lr.ref_type = "check_clearing"
          lr.status = "active"
        end
      else
        LedgerReference.active.find_by(reference: canonical)
      end
    end
  end
end
