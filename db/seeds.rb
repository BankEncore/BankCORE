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
  "transactions.deposit.create" => "Create deposits",
  "transactions.withdrawal.create" => "Create withdrawals",
  "transactions.transfer.create" => "Create transfers",
  "approvals.override.execute" => "Execute supervisor override"
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
      "transactions.deposit.create",
      "transactions.withdrawal.create",
      "transactions.transfer.create"
    ]
  },
  "supervisor" => {
    name: "Supervisor",
    permissions: [
      "sessions.open",
      "sessions.close",
      "teller.dashboard.view",
      "transactions.deposit.create",
      "transactions.withdrawal.create",
      "transactions.transfer.create",
      "approvals.override.execute"
    ]
  },
  "admin" => {
    name: "Administrator",
    permissions: permissions.keys
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
  { email_address: "teller@bankcore.local", role_key: "teller", branch: main_branch, workstation: main_workstation },
  { email_address: "supervisor@bankcore.local", role_key: "supervisor", branch: main_branch, workstation: main_workstation },
  { email_address: "admin@bankcore.local", role_key: "admin", branch: nil, workstation: nil }
]

seed_users.each do |definition|
  user = User.find_or_initialize_by(email_address: definition[:email_address])

  if user.new_record?
    user.password = seed_password
    user.password_confirmation = seed_password
    user.save!
  end

  role = Role.find_by!(key: definition[:role_key])
  UserRole.find_or_create_by!(
    user: user,
    role: role,
    branch: definition[:branch],
    workstation: definition[:workstation]
  )
end
