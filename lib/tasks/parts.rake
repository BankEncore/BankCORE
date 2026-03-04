# frozen_string_literal: true

namespace :parts do
  desc "Build and print legs (FLOW=check_cashing|withdrawal|transfer|deposit|vault_transfer)"
  task print_legs: :environment do
    flow = ENV.fetch("FLOW", "check_cashing")
    legs = build_legs_for(flow)
    puts format_legs(legs)
  end
end

def build_legs_for(flow)
  params = demo_params_for(flow)
  Posting::Parts::PartBuilder.build_entries(flow_type: flow, **params)
end

def demo_params_for(flow)
  amount = ENV["AMOUNT_CENTS"].to_i
  fee = ENV["FEE_CENTS"].to_i
  primary = ENV["PRIMARY_REF"].presence || "acct:123"
  cash = ENV["CASH_REF"].presence || "cash:D01"
  counterparty = ENV["COUNTERPARTY_REF"].presence || "acct:456"

  case flow
  when "check_cashing"
    check_items = ENV["CHECK_ITEMS"]
    items = if check_items.present?
      JSON.parse(check_items)
    else
      [ { "routing" => "021", "account" => "123", "number" => "100", "account_reference" => "check:021:123:100", "amount_cents" => 10_000 } ]
    end
    {
      check_items: items.map(&:symbolize_keys),
      fee_cents: ENV["FEE_CENTS"].present? ? fee : 500,
      cash_account_reference: cash,
      fee_income_account_reference: ENV["FEE_INCOME_REF"].presence || "income:check_cashing_fee"
    }
  when "withdrawal"
    {
      amount_cents: amount.positive? ? amount : 5_000,
      fee_cents: ENV["FEE_CENTS"].present? ? fee : 100,
      primary_account_reference: primary,
      cash_account_reference: cash,
      fee_income_account_reference: ENV["FEE_INCOME_REF"].presence || "income:withdrawal_fee"
    }
  when "transfer"
    {
      amount_cents: amount.positive? ? amount : 1_000,
      fee_cents: ENV["FEE_CENTS"].present? ? fee : 25,
      primary_account_reference: primary,
      counterparty_account_reference: counterparty,
      fee_income_account_reference: ENV["FEE_INCOME_REF"].presence || "income:transfer_fee"
    }
  when "deposit"
    check_items = ENV["CHECK_ITEMS"]
    items = if check_items.present?
      JSON.parse(check_items)
    else
      []
    end
    {
      amount_cents: amount.positive? ? amount : 5_000,
      cash_back_cents: ENV["CASH_BACK_CENTS"].to_i,
      fee_cents: ENV["FEE_CENTS"].present? ? fee : 0,
      check_items: items.map(&:symbolize_keys),
      primary_account_reference: primary,
      cash_account_reference: cash,
      fee_income_account_reference: ENV["FEE_INCOME_REF"].presence || "income:deposit_fee"
    }
  when "vault_transfer"
    source = ENV["SOURCE_REF"].presence || "cash:D01"
    dest = ENV["DEST_REF"].presence || "cash:V01"
    {
      amount_cents: amount.positive? ? amount : 10_000,
      source_cash_account_reference: source,
      destination_cash_account_reference: dest
    }
  else
    raise ArgumentError, "Unknown flow: #{flow}. Use check_cashing, withdrawal, transfer, deposit, or vault_transfer."
  end
end

def format_legs(legs)
  lines = legs.map do |leg|
    "%-6s | %-30s | %10d | %d" % [
      leg[:side],
      leg[:account_reference],
      leg[:amount_cents],
      leg[:position]
    ]
  end
  header = "%-6s | %-30s | %10s | %s" % [ "side", "account_reference", "amount_cents", "position" ]
  [ header, "-" * 60, *lines ].join("\n")
end
