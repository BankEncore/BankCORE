Below is a **concrete Teller layout scaffold** that introduces a dedicated **`layouts/teller.html.erb`** and splits chrome into partials, while **reusing your existing Teller partials** from the archive.

Everything below is intended as **DROP-IN SAFE** given the view structure you provided.

---

# 1) Add a dedicated Teller layout

## `app/views/layouts/teller.html.erb` (new)

```erb
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "BankCORE Teller" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="BankCORE">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body>
    <div class="min-h-screen bg-base-100">
      <%# Teller chrome (workstation feel) %>
      <%= render "teller/shared/topbar", teller_session: (defined?(current_teller_session) ? current_teller_session : Current.teller_session) %>

      <%# Workflow command bar (new) %>
      <%= render "teller/shared/command_bar", teller_session: (defined?(current_teller_session) ? current_teller_session : Current.teller_session) %>

      <main class="mx-auto w-full max-w-7xl p-4 space-y-4">
        <%= render "teller/shared/flash_banners" %>
        <%= yield %>
      </main>
    </div>
  </body>
</html>
```

---

# 2) Add command bar + flash banners partials

## `app/views/teller/shared/_command_bar.html.erb` (new)

This matches your existing routes from `teller/dashboard/index.html.erb`.

```erb
<nav aria-label="Teller Commands" class="border border-base-300 bg-base-100 px-3 py-2">
  <div class="flex flex-wrap gap-2">
    <%= link_to "Dashboard", teller_root_path, class: "btn btn-sm btn-ghost" %>
    <%= link_to "Context", teller_context_path, class: "btn btn-sm btn-ghost" %>

    <% if teller_session.present? %>
      <% if teller_session.cash_location.present? %>
        <%= link_to "Deposit", new_teller_deposit_path, class: "btn btn-sm btn-ghost" %>
        <%= link_to "Withdrawal", new_teller_withdrawal_path, class: "btn btn-sm btn-ghost" %>
        <%= link_to "Check Cashing", new_teller_check_cashing_path, class: "btn btn-sm btn-ghost" %>
      <% end %>

      <%= link_to "Transfer", new_teller_transfer_path, class: "btn btn-sm btn-ghost" %>

      <%# Phase 1 add-ons (link these when routes exist) %>
      <%#= link_to "Bank Draft", new_teller_bank_draft_path, class: "btn btn-sm btn-ghost" %>
      <%#= link_to "Bill Payment", new_teller_bill_payment_path, class: "btn btn-sm btn-ghost" %>
      <%#= link_to "Misc Receipt", new_teller_misc_receipt_path, class: "btn btn-sm btn-ghost" %>
      <%#= link_to "Vault Transfer", new_teller_vault_transfer_path, class: "btn btn-sm btn-ghost" %>
    <% end %>
  </div>
</nav>
```

## `app/views/teller/shared/_flash_banners.html.erb` (new)

```erb
<% if flash[:alert].present? %>
  <div class="alert alert-error"><%= flash[:alert] %></div>
<% end %>

<% if flash[:notice].present? %>
  <div class="alert alert-success"><%= flash[:notice] %></div>
<% end %>
```

---

# 3) Refactor Teller views to rely on the layout (remove duplicated topbar wrappers)

You currently render `teller/shared/topbar` inside every teller page. With the teller layout, **each view should only render its page content**.

## A) `teller/dashboard/index.html.erb` (edit)

**Before:** wraps with `space-y-4` and renders `topbar` + `page_header`
**After:** remove topbar + wrapper div.

```erb
<%= render "teller/shared/page_header",
  title: "Teller Transaction Flows",
  description: "Open a dedicated transaction page for Deposit, Withdrawal, Transfer, or Check Cashing.",
  secondary_button_path: teller_context_path,
  secondary_button_label: "Manage Environment & Session" %>

<% if @teller_session.present? %>
  <section class="card bg-base-100 border border-base-300">
    <div class="card-body">
      <h2 class="card-title text-lg">Transaction Flows</h2>
      <p class="text-sm opacity-80">Open dedicated teller flow pages.</p>
      <div class="flex flex-wrap gap-2">
        <% if @teller_session.cash_location.present? %>
          <%= link_to "Deposit", new_teller_deposit_path, class: "btn btn-outline btn-sm" %>
          <%= link_to "Withdrawal", new_teller_withdrawal_path, class: "btn btn-outline btn-sm" %>
          <%= link_to "Check Cashing", new_teller_check_cashing_path, class: "btn btn-outline btn-sm" %>
        <% end %>
        <%= link_to "Transfer", new_teller_transfer_path, class: "btn btn-outline btn-sm" %>
      </div>
    </div>
  </section>
<% else %>
  <section class="card bg-base-100 border border-base-300">
    <div class="card-body">
      <h2 class="card-title text-lg">Setup Required</h2>
      <p>Set branch/workstation and open a teller session to enable transaction entry.</p>
      <p><%= link_to "Open Session Setup", teller_context_path, class: "btn btn-primary btn-sm" %></p>
    </div>
  </section>
<% end %>
```

## B) `teller/transaction_pages/show.html.erb` (edit)

```erb
<%= render "teller/shared/page_header",
  title: @page_title,
  description: "#{@page_title} flow. Validate and post once balanced.",
  show_state_badge: true,
  initial_state: "Editing",
  secondary_button_action: "posting-form#resetForm",
  secondary_button_label: "Cancel",
  show_primary_submit: true,
  primary_submit_label: "Post Transaction",
  primary_submit_form_id: "posting-form" %>

<%= render "teller/dashboard/posting_workspace",
  teller_session: @teller_session,
  form_url: @form_url,
  default_transaction_type: @transaction_type,
  show_transaction_type: false %>
```

## C) `teller/contexts/show.html.erb` (edit)

```erb
<%= render "teller/shared/page_header",
  title: "Teller Environment & Session",
  description: "Set branch/workstation, then open and manage teller session before posting transactions.",
  secondary_button_path: teller_root_path,
  secondary_button_label: "Go to Transaction Flows" %>

<%= render "teller/dashboard/session_context_card", branches: @branches, workstations: @workstations %>
<%= render "teller/dashboard/teller_session_card", teller_session: @teller_session, drawers: @drawers %>
```

## D) `teller/receipts/show.html.erb` (edit)

Remove the topbar wrapper line only:

```diff
- <%= render "teller/shared/topbar", teller_session: current_teller_session %>
```

Leave the rest unchanged.

---

# 4) Tell Rails to use the Teller layout for Teller controllers

In your teller base controller (or each teller controller), set:

```ruby
layout "teller"
```

Examples:

```ruby
class Teller::BaseController < ApplicationController
  layout "teller"
end
```

or per-controller:

```ruby
class Teller::DashboardController < ApplicationController
  layout "teller"
end
```

---

# 5) Optional: keep `application.html.erb` “webby” and Teller “workstation”

This lets you keep your current global navbar for non-teller parts, while Teller gets the serious workstation chrome.

If you want, I can also provide a **light edit** to `application.html.erb` so the header becomes a thin utility bar (and hides the “Home/Teller/Teller Context” buttons when inside `/teller`), but the scaffold above does not require it.

---

## If you upload one more thing, I can tighten this further

To make the command bar fully Phase 1 complete (including Draft/Bill/Misc/Vault links), upload your current `/teller` section of `config/routes.rb` (paste is fine).
