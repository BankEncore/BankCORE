# frozen_string_literal: true

namespace :parts do
  desc "Build and print legs (FLOW=check_cashing|withdrawal|transfer|deposit|vault_transfer|misc_receipt|draft|bill_payment)"
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
  when "misc_receipt"
    misc_cash = ENV["MISC_CASH_CENTS"].to_i
    misc_account = ENV["MISC_ACCOUNT_CENTS"].to_i
    amt = amount.positive? ? amount : 5_000
    misc_cash = amt if misc_cash.zero? && misc_account.zero?
    {
      amount_cents: amt,
      misc_cash_cents: misc_cash,
      misc_account_cents: misc_account,
      check_items: [],
      primary_account_reference: primary,
      cash_account_reference: cash,
      income_account_reference: ENV["INCOME_REF"].presence || "income:misc_receipt"
    }
  when "draft"
    draft_amt = ENV["DRAFT_AMOUNT_CENTS"].to_i
    draft_amt = 3_000 if draft_amt.zero?
    draft_fee = ENV["DRAFT_FEE_CENTS"].to_i
    draft_cash = ENV["DRAFT_CASH_CENTS"].to_i
    draft_account = ENV["DRAFT_ACCOUNT_CENTS"].to_i
    draft_cash = draft_amt + draft_fee if draft_cash.zero? && draft_account.zero?
    {
      draft_amount_cents: draft_amt,
      draft_fee_cents: draft_fee,
      draft_cash_cents: draft_cash,
      draft_account_cents: draft_account,
      check_items: [],
      primary_account_reference: primary,
      cash_account_reference: cash,
      draft_liability_account_reference: ENV["LIABILITY_REF"].presence || "official_check:outstanding",
      draft_fee_income_account_reference: ENV["FEE_INCOME_REF"].presence || "income:draft_fee"
    }
  when "bill_payment"
    payment = ENV["PAYMENT_CENTS"].to_i
    payment = 2_000 if payment.zero?
    bp_fee = ENV["FEE_CENTS"].to_i
    bp_cash = ENV["BILL_PAYMENT_CASH_CENTS"].to_i
    bp_account = ENV["BILL_PAYMENT_ACCOUNT_CENTS"].to_i
    bp_cash = payment + bp_fee if bp_cash.zero? && bp_account.zero?
    {
      payment_cents: payment,
      fee_cents: bp_fee,
      bill_payment_cash_cents: bp_cash,
      bill_payment_account_cents: bp_account,
      check_items: [],
      primary_account_reference: primary,
      cash_account_reference: cash,
      liability_account_reference: ENV["LIABILITY_REF"].presence || "bill_pmt:default",
      fee_income_account_reference: ENV["FEE_INCOME_REF"].presence || "income:bill_payment_fee"
    }
  else
    raise ArgumentError, "Unknown flow: #{flow}. Use check_cashing, withdrawal, transfer, deposit, vault_transfer, misc_receipt, draft, or bill_payment."
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
