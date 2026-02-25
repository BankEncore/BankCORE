module ApplicationHelper
  def authorized_workspaces
    return [] unless Current.user.present?

    workspaces = []
    workspaces << { name: "Teller Workspace", path: teller_root_path, active: controller_path.start_with?("teller/") } if Current.user.has_permission?("teller.dashboard.view")
    workspaces << { name: "CSR Workspace", path: csr_root_path, active: controller_path.start_with?("csr/") } if Current.user.has_permission?("csr.dashboard.view")
    workspaces << { name: "Operations Workspace", path: ops_root_path, active: controller_path.start_with?("ops/") }
    workspaces << { name: "Administration Workspace", path: admin_root_path, active: controller_path.start_with?("admin/") } if Current.user.has_permission?("administration.workspace.view")
    workspaces
  end

  def current_workspace_label
    return "BankCORE" unless Current.user.present?

    if controller_path.start_with?("teller/") then "Teller Workspace"
    elsif controller_path.start_with?("csr/") then "CSR Workspace"
    elsif controller_path.start_with?("ops/") then "Operations Workspace"
    elsif controller_path.start_with?("admin/") then "Administration Workspace"
    else "BankCORE"
    end
  end

  def switch_branch_path
    if controller_path.start_with?("teller/") then teller_context_path
    elsif controller_path.start_with?("csr/") then csr_context_path
    else teller_context_path
    end
  end

  def mask_last_four(value, placeholder: "•")
    return "—" if value.blank?
    str = value.to_s.strip.gsub(/\D/, "")
    return "—" if str.length < 4
    last_four = str[-4, 4]
    prefix_len = [ str.length - 4, 0 ].max
    "#{placeholder * prefix_len}#{last_four}"
  end
end
