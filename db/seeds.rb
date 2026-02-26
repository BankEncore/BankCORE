# frozen_string_literal: true

# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require "csv"

SEED_DATA_DIR = Rails.root.join("docs", "seed_data")

def branch_by_code(code)
  Branch.find_or_create_by!(code: code.to_s.strip) do |b|
    b.name = case code.to_s.strip
    when "005" then "Fifth Branch"
    else "Branch #{code}"
    end
  end
end

# --- Permissions and Roles ---

permissions = {
  "sessions.open" => "Open teller session",
  "sessions.close" => "Close teller session",
  "teller.dashboard.view" => "Access teller dashboard",
  "csr.dashboard.view" => "Access CSR workspace (customer and account management)",
  "transactions.deposit.create" => "Create deposits",
  "transactions.withdrawal.create" => "Create withdrawals",
  "transactions.transfer.create" => "Create transfers",
  "transactions.vault_transfer.create" => "Create vault transfers",
  "transactions.draft.create" => "Create draft issuances",
  "transactions.check_cashing.create" => "Create check cashing transactions",
  "transactions.reversal.create" => "Initiate transaction reversals",
  "approvals.override.execute" => "Execute supervisor override",
  "accounts.branch.edit" => "Edit account branch (managers only)",
  "administration.workspace.view" => "Access Administration workspace (manage branches, cash locations, users, roles)"
}

permissions.each do |key, description|
  Permission.find_or_create_by!(key: key) do |permission|
    permission.description = description
  end
end

roles = {
  "teller" => {
    name: "Teller",
    permissions: [
      "sessions.open",
      "sessions.close",
      "teller.dashboard.view",
      "csr.dashboard.view",
      "transactions.deposit.create",
      "transactions.withdrawal.create",
      "transactions.transfer.create",
      "transactions.vault_transfer.create",
      "transactions.draft.create",
      "transactions.check_cashing.create",
      "transactions.reversal.create"
    ]
  },
  "supervisor" => {
    name: "Supervisor",
    permissions: [
      "sessions.open",
      "sessions.close",
      "teller.dashboard.view",
      "csr.dashboard.view",
      "transactions.deposit.create",
      "transactions.withdrawal.create",
      "transactions.transfer.create",
      "transactions.vault_transfer.create",
      "transactions.draft.create",
      "transactions.check_cashing.create",
      "transactions.reversal.create",
      "approvals.override.execute",
      "accounts.branch.edit"
    ]
  },
  "admin" => {
    name: "Administrator",
    permissions: permissions.keys
  },
  "csr" => {
    name: "Customer Service Representative",
    permissions: [ "csr.dashboard.view" ]
  }
}

roles.each do |key, definition|
  role = Role.find_or_create_by!(key: key) do |record|
    record.name = definition[:name]
  end

  definition[:permissions].each do |permission_key|
    permission = Permission.find_by!(key: permission_key)
    RolePermission.find_or_create_by!(role: role, permission: permission)
  end
end

# --- Branches from CSV ---

branches_path = SEED_DATA_DIR.join("UI - Branches.csv")
if File.exist?(branches_path)
  CSV.foreach(branches_path, headers: true) do |row|
    code = row["code"]&.strip
    name = row["name"]&.strip
    next if code.blank?
    Branch.find_or_create_by!(code: code) { |b| b.name = name.presence || "Branch #{code}" }
  end
end

# --- Cash Locations from CSV ---

cash_locations_path = SEED_DATA_DIR.join("UI - Cash Locations.csv")
if File.exist?(cash_locations_path)
  CSV.foreach(cash_locations_path, headers: true) do |row|
    branch_code = row["branch_code"]&.strip
    code = row["code"]&.strip
    name = row["name"]&.strip
    next if branch_code.blank? || code.blank?
    branch = branch_by_code(branch_code)
    location_type = name.to_s.include?("Vault") ? "vault" : "drawer"
    CashLocation.find_or_create_by!(branch: branch, code: code) do |cl|
      cl.name = name.presence || code
      cl.location_type = location_type
    end
  end
end

# --- Workstations from CSV ---

workstations_path = SEED_DATA_DIR.join("UI - Workstations.csv")
if File.exist?(workstations_path)
  CSV.foreach(workstations_path, headers: true) do |row|
    branch_code = row["branch_code"]&.strip
    code = row["code"]&.strip
    name = row["name"]&.strip
    next if branch_code.blank? || code.blank?
    branch = branch_by_code(branch_code)
    Workstation.find_or_create_by!(branch: branch, code: code) { |w| w.name = name.presence || code }
  end
end

# --- Users (Tellers) from CSV ---

main_branch = Branch.find_by(code: "001")
main_workstation = main_branch&.workstations&.find_by(code: "T01")
seed_password = ENV.fetch("SEED_USER_PASSWORD", "ChangeMe123!")

tellers_path = SEED_DATA_DIR.join("UI - Tellers.csv")
if File.exist?(tellers_path)
  CSV.foreach(tellers_path, headers: true) do |row|
    email = row["email_address"]&.strip&.downcase
    next if email.blank?

    user = User.find_or_initialize_by(email_address: email)
    user.first_name = row["first_name"]&.strip
    user.last_name = row["last_name"]&.strip
    user.teller_number = row["teller_number"]&.strip&.slice(0, 4)
    user.default_workspace = case row["default_workspace"]&.strip&.downcase
    when "operations" then "ops"
    when "teller", "csr", "admin" then row["default_workspace"]&.strip&.downcase
    else nil
    end

    if user.new_record?
      user.password = row["password"]&.strip.presence || seed_password
      user.password_confirmation = user.password
      user.save!
    else
      user.save! if user.changed?
    end

    user.pin = row["pin"]&.strip if row["pin"]&.strip.present?
    user.save! if user.changed?

    role_key = row["role"]&.strip&.downcase
    role = Role.find_by(key: role_key)
    next unless role

    branch = nil
    workstation = nil
    case role_key
    when "admin"
      branch = nil
      workstation = nil
    when "supervisor", "teller"
      branch = main_branch
      workstation = main_workstation
    when "csr"
      branch = main_branch
      workstation = nil
    end

    UserRole.find_or_create_by!(user: user, role: role, branch: branch, workstation: workstation)
  end
end

# --- Organizations + Accounts from CSV ---

orgs_path = SEED_DATA_DIR.join("UI - Organization Profiles_Accounts.csv")
if File.exist?(orgs_path)
  CSV.foreach(orgs_path, headers: true) do |row|
    legal_name = row["Legal Name"]&.strip
    next if legal_name.blank?

    party = Party.joins(:party_organization).find_by(party_organizations: { legal_name: legal_name })
    unless party
      party = Party.create!(
        party_kind: "organization",
        relationship_kind: "customer",
        is_active: true,
        email: row["Email"]&.strip.presence,
        phone: row["Phone"]&.strip.presence,
        street_address: row["Street"]&.strip.presence,
        city: row["City"]&.strip.presence,
        state: row["State"]&.strip.presence,
        zip_code: row["ZIP"]&.strip.presence,
        tax_id: row["Tax ID"]&.strip.presence
      )
      party.create_party_organization!(
        legal_name: legal_name,
        dba_name: row["DBA Name"]&.strip.presence
      )
    end

    account_number = row["Checking Account"]&.strip
    branch_code = row["Branch"]&.strip
    next if account_number.blank? || branch_code.blank?

    branch = branch_by_code(branch_code)
    opened_on = begin
      Date.parse(row["Date Opened"].to_s)
    rescue ArgumentError
      Date.current
    end

    account = Account.find_or_create_by!(account_number: account_number) do |a|
      a.account_type = "checking"
      a.branch = branch
      a.status = "open"
      a.opened_on = opened_on
      a.last_activity_at = Time.current
    end

    AccountOwner.find_or_create_by!(account: account, party: party) { |ao| ao.is_primary = true }
  end
end

# --- Individuals + Accounts from CSV ---

indiv_path = SEED_DATA_DIR.join("UI - Invidividual Parties_Accounts.csv")
if File.exist?(indiv_path)
  CSV.foreach(indiv_path, headers: true) do |row|
    first_name = row["First Name"]&.strip
    last_name = row["Last Name"]&.strip
    next if first_name.blank? || last_name.blank?

    party = Party.joins(:party_individual).find_by(
      party_individuals: { first_name: first_name, last_name: last_name }
    )
    unless party
      party = Party.create!(
        party_kind: "individual",
        relationship_kind: "customer",
        is_active: true,
        email: row["Email Address"]&.strip.presence,
        phone: row["Phone"]&.strip.presence,
        street_address: row["Street"]&.strip.presence,
        city: row["City"]&.strip.presence,
        state: row["State"]&.strip.presence,
        zip_code: row["ZIP"]&.strip.presence,
        tax_id: row["Tax ID"]&.strip.presence
      )
      dob = begin
        Date.parse(row["Birth Date"].to_s)
      rescue ArgumentError
        nil
      end
      govt_id_type_raw = row["Govt ID Type"]&.strip&.downcase
      govt_id_type = case govt_id_type_raw
      when "driver_license", "driver license" then "driver_license"
      when "state_id", "state id" then "state_id"
      when "passport" then "passport"
      else "other"
      end
      party.create_party_individual!(
        first_name: first_name,
        last_name: last_name,
        dob: dob,
        govt_id: row["Govt ID"]&.strip.presence,
        govt_id_type: govt_id_type
      )
    end

    branch_code = row["Branch"]&.strip
    opened_on = begin
      Date.parse(row["Date Opened"].to_s)
    rescue ArgumentError
      Date.current
    end
    next if branch_code.blank?

    branch = branch_by_code(branch_code)

    [ row["Checking Account"], row["Savings Account"] ].each_with_index do |acct_num, idx|
      next if acct_num.blank?
      account_type = idx == 0 ? "checking" : "savings"

      account = Account.find_or_create_by!(account_number: acct_num.to_s.strip) do |a|
        a.account_type = account_type
        a.branch = branch
        a.status = "open"
        a.opened_on = opened_on
        a.last_activity_at = Time.current
      end

      AccountOwner.find_or_create_by!(account: account, party: party) { |ao| ao.is_primary = true }
    end
  end
end
