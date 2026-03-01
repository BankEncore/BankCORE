# frozen_string_literal: true

class DenominationBreakdownService
  attr_reader :errors

  def initialize
    @errors = []
  end

  # @param lines_params [Array<Hash>] e.g. [ { "cash_denomination_id" => "1", "qty" => "5", "amount_cents" => "500" }, ... ]
  # @param catalog [Array<CashDenomination>]
  # @return [Array<Hash>] validated lines with :cash_denomination_id, :qty, :amount_cents (and errors populated)
  def parse_and_validate(lines_params, catalog)
    return [] if lines_params.blank?

    catalog_by_id = catalog.index_by(&:id)
    validated = []

    Array(lines_params).each do |raw|
      denom_id = raw["cash_denomination_id"].to_s.strip.presence&.to_i
      next if denom_id.blank?

      denom = catalog_by_id[denom_id]
      unless denom
        @errors << "Unknown cash denomination ID: #{denom_id}"
        next
      end

      qty_raw = raw["qty"].to_s.strip
      amount_raw = raw["amount_cents"].to_s.strip

      qty = qty_raw.presence&.to_i
      amount_cents = parse_cents(amount_raw) || (qty && qty >= 0 ? qty * denom.unit_value_cents : 0)

      # Single source of truth: qty takes precedence if entered
      if qty.present? && qty >= 0
        expected_amount = qty * denom.unit_value_cents
        if amount_raw.present? && parse_cents(amount_raw).to_i != expected_amount
          @errors << "#{denom.display_label}: amount must equal qty × unit value (#{expected_amount}¢)"
        end
        amount_cents = expected_amount
      elsif amount_cents.positive?
        if denom.must_divide_evenly?
          unit = denom.unit_value_cents
          if amount_cents % unit != 0
            @errors << "#{denom.display_label}: amount must be a multiple of #{unit}¢"
          else
            qty = amount_cents / unit
          end
        end
      else
        next # skip zero lines
      end

      validated << {
        cash_denomination_id: denom_id,
        qty: qty,
        amount_cents: amount_cents
      }
    end

    validated
  end

  # @param lines [Array<Hash>] with :amount_cents
  # @return [Integer] total cents
  def total_from_lines(lines)
    Array(lines).sum { |l| (l[:amount_cents] || l["amount_cents"] || 0).to_i }
  end

  # @param denominationable [TellerTransaction, TellerSession]
  # @param lines [Array<Hash>] validated lines
  # @param context [String, nil] optional: "opening", "closing" for TellerSession
  # @return [DenominationSet, nil]
  def persist!(denominationable, lines, context: nil)
    total = total_from_lines(lines)
    return nil if total.zero?

    set = if denominationable.is_a?(TellerSession)
      denominationable.denomination_sets.find_or_initialize_by(context: context)
    else
      denominationable.denomination_set || denominationable.build_denomination_set
    end

    set.currency = "USD"
    set.total_cents = total
    set.save!

    set.denomination_lines.destroy_all

    lines.each do |line|
      set.denomination_lines.create!(
        cash_denomination_id: line[:cash_denomination_id],
        qty: line[:qty],
        amount_cents: line[:amount_cents]
      )
    end

    set
  end

  private

    def parse_cents(str)
      return nil if str.blank?
      val = str.to_s.gsub(/[$,]/, "").strip
      return nil if val.blank?
      (val.to_f * 100).round
    end
end
