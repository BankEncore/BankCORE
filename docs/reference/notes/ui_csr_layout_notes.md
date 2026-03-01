## CSR layout wrapper (small, consistent rhythm)

**CONCEPTUAL** (since I don’t have your current repo snapshot/structure). This is designed to be low-risk and easy to adapt.

---

# 1) Add a dedicated CSR layout

### `app/views/layouts/csr.html.erb`

```erb
<%# CSR layout: consistent page width + vertical rhythm for record screens %>

<%= render "shared/app_shell" do %>
  <main class="px-4 py-4">
    <div class="mx-auto max-w-6xl">
      <%# Optional: page-level flash/messages %>
      <%= render "shared/flash" if lookup_context.exists?("shared/_flash") %>

      <div class="space-y-4">
        <%= yield %>
      </div>
    </div>
  </main>
<% end %>
```

Notes:

* `max-w-6xl` is a solid “desktop workstation” width.
* `space-y-4` becomes the *single source of truth* for section spacing (`mb-4` becomes optional).
* This assumes you have a top-level shell partial (common in your apps). If not, swap `shared/app_shell` for your existing layout structure.

---

# 2) Route CSR controllers to use the CSR layout

### `app/controllers/csr/base_controller.rb`

```ruby
class Csr::BaseController < ApplicationController
  layout "csr"
end
```

Then make CSR controllers inherit:

```ruby
class Csr::AccountsController < Csr::BaseController
  # ...
end
```

If you already have `Csr::BaseController`, just add `layout "csr"` there.

---

# 3) Provide a tiny wrapper partial for “record screens”

This wrapper standardizes *record screen semantics* without repeating container rules per view.

### `app/views/csr/shared/_record_screen.html.erb`

```erb
<%# Usage: render "csr/shared/record_screen" do ... end %>
<section class="space-y-4">
  <%= yield %>
</section>
```

Yes, it’s intentionally small. The power is: every record screen now has one canonical wrapper.

---

# 4) Provide a unified header partial (block-based actions)

### `app/views/csr/shared/_record_header.html.erb`

```erb
<%# locals: title:, subtitle: nil, status: nil %>

<section>
  <div class="flex items-start justify-between gap-6">
    <div>
      <div class="flex items-center gap-3">
        <h1 class="text-lg font-semibold tracking-tight">
          <%= title %>
        </h1>

        <% if status.present? %>
          <span class="badge badge-outline">
            <%= status %>
          </span>
        <% end %>
      </div>

      <% if subtitle.present? %>
        <div class="mt-1 text-sm text-base-content/60">
          <%= subtitle %>
        </div>
      <% end %>
    </div>

    <div class="flex items-center gap-2">
      <%= yield :actions %>
    </div>
  </div>

  <div class="mt-3 border-b border-base-300"></div>
</section>
```

This avoids needing `primary_button_path`, `secondary_button_path`, etc. Callers can define exactly what buttons appear.

---

# 5) Standardize record “panels” (optional, but helpful)

### `app/views/csr/shared/_panel.html.erb`

```erb
<%# locals: title:, right: nil %>
<section class="card bg-base-100 border border-base-300">
  <div class="card-body">
    <div class="flex items-center justify-between gap-3">
      <h2 class="card-title text-base"><%= title %></h2>
      <% if right.present? %>
        <div class="text-sm text-base-content/60"><%= right %></div>
      <% end %>
    </div>

    <div class="mt-3">
      <%= yield %>
    </div>
  </div>
</section>
```

Now “Details”, “Owners”, “Documents”, “Flags”, etc. all look identical without repeated markup.

---

# 6) Example: refactor your Account show view to use the wrapper

### `app/views/csr/accounts/show.html.erb`

```erb
<%= render "csr/shared/record_screen" do %>

  <%= render "csr/shared/record_header",
    title: "Account #{@account.account_number}",
    subtitle: "#{@account.account_type.titleize} • #{@account.branch.name}",
    status: @account.status do |h| %>
      <% h.content_for :actions do %>
        <%= link_to "Back to Accounts", csr_accounts_path, class: "btn btn-sm btn-ghost" %>
        <%= link_to "Edit", edit_csr_account_path(@account), class: "btn btn-sm btn-primary" %>
      <% end %>
  <% end %>

  <%= render "csr/shared/panel", title: "Details" do %>
    <dl class="divide-y divide-base-300/60 text-sm">
      <div class="flex items-center justify-between gap-6 py-2">
        <dt class="text-base-content/70">Account number</dt>
        <dd class="font-mono tabular-nums"><%= @account.account_number %></dd>
      </div>
      <div class="flex items-center justify-between gap-6 py-2">
        <dt class="text-base-content/70">Posting reference</dt>
        <dd class="font-mono tabular-nums"><%= @account.account_reference %></dd>
      </div>
      <div class="flex items-center justify-between gap-6 py-2">
        <dt class="text-base-content/70">Type</dt>
        <dd><%= @account.account_type.titleize %></dd>
      </div>
      <div class="flex items-center justify-between gap-6 py-2">
        <dt class="text-base-content/70">Branch</dt>
        <dd><%= @account.branch.name %></dd>
      </div>
      <div class="flex items-center justify-between gap-6 py-2">
        <dt class="text-base-content/70">Opened</dt>
        <dd class="tabular-nums"><%= @account.opened_on&.strftime("%Y-%m-%d") || "—" %></dd>
      </div>
      <div class="flex items-center justify-between gap-6 py-2">
        <dt class="text-base-content/70">Closed</dt>
        <dd class="tabular-nums"><%= @account.closed_on&.strftime("%Y-%m-%d") || "—" %></dd>
      </div>
    </dl>
  <% end %>

  <%= render "shared/accounts/balance_and_history",
    account: @account,
    account_transactions: @account_transactions,
    sections: [:balance] %>

  <%= render "csr/shared/panel", title: "Owners", right: "#{@account.account_owners.size} total" do %>
    <div class="overflow-x-auto">
      <table class="table table-sm">
        <thead>
          <tr>
            <th>Party</th>
            <th class="w-28">Primary</th>
          </tr>
        </thead>
        <tbody>
          <% @account.account_owners.includes(:party).each do |ao| %>
            <tr class="hover">
              <td>
                <%= link_to(
                      ao.party.display_name.presence || "Party ##{ao.party_id}",
                      csr_party_path(ao.party),
                      class: "link"
                    ) %>
              </td>
              <td>
                <% if ao.is_primary? %>
                  <span class="badge badge-outline">Primary</span>
                <% else %>
                  <span class="text-base-content/50">—</span>
                <% end %>
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
  <% end %>

  <%= render "shared/accounts/balance_and_history",
    account: @account,
    account_transactions: @account_transactions,
    sections: [:history] %>

<% end %>
```

Key outcome:

* All major sections inherit spacing automatically via `space-y-4`.
* Panels are standardized via one partial.
* Header is standardized and flexible.

---

# 7) Minimal governance rules (enforceable)

Once this is in place, you can adopt these two rules:

1. **Every CSR show page** must be wrapped in `csr/shared/record_screen`.
2. **Every section** must be a `csr/shared/panel` unless it’s a specialized component (like your `balance_and_history` partial).

This prevents drift.

---

If you share your current main application layout file path (e.g., `app/views/layouts/application.html.erb` and any shell partials), I can adjust the `csr.html.erb` to match your actual structure exactly (still keeping this wrapper pattern).
