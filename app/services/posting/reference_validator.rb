# frozen_string_literal: true

module Posting
  class ReferenceValidator
    def self.call(legs:, error_class: Posting::Engine::Error)
      new(legs: legs, error_class: error_class).call
    end

    def initialize(legs:, error_class: Posting::Engine::Error)
      @legs = legs
      @error_class = error_class
    end

    def call
      legs.each do |leg|
        reference = leg.fetch(:account_reference).to_s.strip
        next if reference.blank?

        LedgerReferences::Resolver.call(reference: reference)
      end
    rescue LedgerReferences::Resolver::UnresolvedReference => e
      raise error_class, "Unknown account reference: #{e.reference.inspect}"
    end

    private

    attr_reader :legs, :error_class
  end
end
