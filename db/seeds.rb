# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

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
      "approvals.override.execute"
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

main_branch = Branch.find_or_create_by!(code: "001") do |branch|
  branch.name = "Main Branch"
end

main_workstation = Workstation.find_or_create_by!(branch: main_branch, code: "T01") do |workstation|
  workstation.name = "Teller 01"
end

CashLocation.find_or_create_by!(branch: main_branch, code: "D01") do |cash_location|
  cash_location.name = "Drawer 01"
  cash_location.location_type = "drawer"
end

CashLocation.find_or_create_by!(branch: main_branch, code: "V01") do |cash_location|
  cash_location.name = "Main Vault"
  cash_location.location_type = "vault"
end

seed_password = ENV.fetch("SEED_USER_PASSWORD", "ChangeMe123!")

seed_users = [
  { email_address: "teller@bankcore.local", first_name: "Tina", last_name: "Teller", teller_number: "T001", role_key: "teller", branch: main_branch, workstation: main_workstation },
  { email_address: "supervisor@bankcore.local", first_name: "Sam", last_name: "Supervisor", teller_number: "S001", role_key: "supervisor", branch: main_branch, workstation: main_workstation },
  { email_address: "admin@bankcore.local", first_name: "Admin", last_name: "User", teller_number: "A001", role_key: "admin", branch: nil, workstation: nil },
  { email_address: "csr@bankcore.local", first_name: "Chris", last_name: "CSR", teller_number: "C001", role_key: "csr", branch: main_branch, workstation: nil }
]

seed_users.each do |definition|
  user = User.find_or_initialize_by(email_address: definition[:email_address])
  user.first_name = definition[:first_name] if definition[:first_name]
  user.last_name = definition[:last_name] if definition[:last_name]
  user.teller_number = definition[:teller_number] if definition[:teller_number]

  if user.new_record?
    user.password = seed_password
    user.password_confirmation = seed_password
    user.save!
  else
    user.save! if user.changed?
  end

  role = Role.find_by!(key: definition[:role_key])
  UserRole.find_or_create_by!(
    user: user,
    role: role,
    branch: definition[:branch],
    workstation: definition[:workstation]
  )
end

# CIF: Sample parties and accounts for teller tests
party_jane = Party.joins(:party_individual).find_by(party_individuals: { first_name: "Jane", last_name: "Doe" })
unless party_jane
  party_jane = Party.create!(party_kind: "individual", relationship_kind: "customer", is_active: true)
  party_jane.create_party_individual!(first_name: "Jane", last_name: "Doe")
end

party_acme = Party.joins(:party_organization).find_by(party_organizations: { legal_name: "Acme Corp" })
unless party_acme
  party_acme = Party.create!(party_kind: "organization", relationship_kind: "customer", is_active: true)
  party_acme.create_party_organization!(legal_name: "Acme Corp", dba_name: "Acme")
end

Account.find_or_create_by!(account_number: "1000000000001001") do |a|
  a.account_type = "checking"
  a.branch = main_branch
  a.status = "open"
  a.opened_on = Date.current
  a.last_activity_at = Time.current
end.tap do |account|
  unless account.account_owners.exists?(party: party_jane)
    AccountOwner.create!(account: account, party: party_jane, is_primary: true)
  end
end

Account.find_or_create_by!(account_number: "1000000000001002") do |a|
  a.account_type = "savings"
  a.branch = main_branch
  a.status = "open"
  a.opened_on = Date.current
  a.last_activity_at = Time.current
end.tap do |account|
  unless account.account_owners.exists?(party: party_acme)
    AccountOwner.create!(account: account, party: party_acme, is_primary: true)
  end
end
