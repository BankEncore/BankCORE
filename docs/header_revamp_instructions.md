## DROP-IN SAFE refactor: “Global header always on top” + “Workspace” switcher

This keeps your current structure, but introduces a **single global header band** shared by both layouts, and renames “Areas” to **Workspaces**.

### 1) Add a shared global header partial

Create: `app/views/shared/_global_header.html.erb`

```erb
<%# Shared global header: identity + workspace navigation + user/logout %>
<% teller_active = controller_path.start_with?("teller/") %>
<% ops_active    = controller_path.start_with?("ops/") %>

<header class="border-b border-base-300 bg-base-200/70 px-4">
  <div class="navbar min-h-0 py-2 px-0">
    <div class="flex-1 items-center gap-3">
      <%= link_to "BankCORE", root_path, class: "text-lg font-semibold tracking-wide" %>

      <nav class="flex items-center gap-2 text-sm" aria-label="Primary">
        <%= link_to "Home",
                    root_path,
                    class: "btn btn-ghost btn-sm #{current_page?(root_path) ? "btn-active" : ""}",
                    aria: (current_page?(root_path) ? { current: "page" } : {}) %>

        <details class="dropdown">
          <summary class="btn btn-ghost btn-sm <%= (teller_active || ops_active) ? "btn-active" : "" %>">
            Workspace
          </summary>

          <ul class="menu dropdown-content z-[1] mt-2 w-56 rounded-box border border-base-300 bg-base-100 p-2 shadow">
            <li>
              <%= link_to "Teller Workspace",
                          teller_root_path,
                          class: (teller_active ? "active" : nil) %>
            </li>
            <li>
              <%= link_to "Operations Workspace",
                          ops_root_path,
                          class: (ops_active ? "active" : nil) %>
            </li>
          </ul>
        </details>
      </nav>
    </div>

    <div class="flex-none flex flex-wrap items-center gap-2 text-sm">
      <%# Keep this subtle; don’t over-stuff the global band %>
      <span class="badge badge-outline">
        <%= Current.user&.email_address || "Signed in" %>
      </span>

      <% if Current.teller_session&.id.present? %>
        <span class="badge badge-outline">
          Teller Session:
          <span class="tabular-nums"><%= Current.teller_session.id %></span>
        </span>
      <% end %>

      <%= button_to "Log out", session_path, method: :delete, class: "btn btn-ghost btn-sm" %>
    </div>
  </div>
</header>
```

---

## 2) Drop-in replacement: `app/views/layouts/application.html.erb`

```erb
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "BankCORE" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="BankCORE">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <%# Enable PWA manifest for installable apps (make sure to enable in config/routes.rb too!) %>
    <%#= tag.link rel: "manifest", href: pwa_manifest_path(format: :json) %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="bg-base-100">
    <a href="#main" class="sr-only focus:not-sr-only focus:absolute focus:z-[9999] focus:m-3 focus:rounded focus:bg-base-100 focus:px-3 focus:py-2 focus:shadow">
      Skip to content
    </a>

    <div class="min-h-screen">
      <% if authenticated? %>
        <div class="sticky top-0 z-50">
          <%= render "shared/global_header" %>
        </div>
      <% end %>

      <main id="main" class="mx-auto w-full max-w-7xl px-4 py-3 space-y-3">
        <%= tag.div(flash[:alert], class: "alert alert-error") if flash[:alert] %>
        <%= tag.div(flash[:notice], class: "alert alert-success") if flash[:notice] %>
        <%= yield %>
      </main>
    </div>
  </body>
</html>
```

---

## 3) Drop-in replacement: `app/views/layouts/teller.html.erb`

This keeps your teller topbar + command bar, but ensures the **global header is always the top band**.

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

  <body class="bg-base-100">
    <a href="#main" class="sr-only focus:not-sr-only focus:absolute focus:z-[9999] focus:m-3 focus:rounded focus:bg-base-100 focus:px-3 focus:py-2 focus:shadow">
      Skip to content
    </a>

    <div class="min-h-screen">
      <div class="sticky top-0 z-50">
        <%# Global shell band (always first) %>
        <%= render "shared/global_header" %>

        <%# Teller workspace bands %>
        <%= render "teller/shared/topbar", teller_session: current_teller_session %>
        <%= render "teller/shared/command_bar", teller_session: current_teller_session %>
      </div>

      <main id="main" class="mx-auto w-full max-w-7xl px-4 py-3 space-y-3">
        <%= render "teller/shared/flash_banners" %>
        <%= yield %>
      </main>
    </div>
  </body>
</html>
```

---

## Notes (why this matches your UI goals)

* **Global header is always on top** (consistent shell, regulator-friendly predictability)
* **Workspaces** is a better term than “Areas” for BankCORE (mode/role-based navigation)
* **Teller workflow commands stay out of the global header** (keeps the top band conservative and uncluttered)

If you want to go one step further, the next incremental improvement is to remove “Teller Session” from the global header and show it only in the Teller topbar (so Ops doesn’t inherit teller-specific concepts).


## DROP-IN SAFE: remove Teller Session from the global header (show teller-only context in teller bands)

### 1) Update `app/views/shared/_global_header.html.erb`

This version:

* Renames the switcher to **Workspace**
* Shows **only global concepts**: identity, workspace nav, signed-in user, logout
* **Removes Teller Session** entirely

```erb
<%# Shared global header: identity + workspace navigation + user/logout (no teller-specific context) %>
<% teller_active = controller_path.start_with?("teller/") %>
<% ops_active    = controller_path.start_with?("ops/") %>

<header class="border-b border-base-300 bg-base-200/70 px-4">
  <div class="navbar min-h-0 py-2 px-0">
    <div class="flex-1 items-center gap-3">
      <%= link_to "BankCORE", root_path, class: "text-lg font-semibold tracking-wide" %>

      <nav class="flex items-center gap-2 text-sm" aria-label="Primary">
        <%= link_to "Home",
                    root_path,
                    class: "btn btn-ghost btn-sm #{current_page?(root_path) ? "btn-active" : ""}",
                    aria: (current_page?(root_path) ? { current: "page" } : {}) %>

        <details class="dropdown">
          <summary class="btn btn-ghost btn-sm <%= (teller_active || ops_active) ? "btn-active" : "" %>">
            Workspace
          </summary>

          <ul class="menu dropdown-content z-[1] mt-2 w-56 rounded-box border border-base-300 bg-base-100 p-2 shadow">
            <li>
              <%= link_to "Teller Workspace",
                          teller_root_path,
                          class: (teller_active ? "active" : nil) %>
            </li>
            <li>
              <%= link_to "Operations Workspace",
                          ops_root_path,
                          class: (ops_active ? "active" : nil) %>
            </li>
          </ul>
        </details>
      </nav>
    </div>

    <div class="flex-none flex flex-wrap items-center gap-2 text-sm">
      <span class="badge badge-outline">
        <%= Current.user&.email_address || "Signed in" %>
      </span>

      <%= button_to "Log out", session_path, method: :delete, class: "btn btn-ghost btn-sm" %>
    </div>
  </div>
</header>
```

---

## 2) Ensure Teller Session is shown in the Teller context band instead

Your teller layout already renders `teller/shared/topbar`. That’s the correct place for:

* Session
* Drawer
* Branch
* Workstation
* Teller

So no change is required in the layouts beyond using the updated global header.

If your current `teller/shared/_topbar.html.erb` **doesn’t** show session/drawer, paste it and I’ll give a drop-in version that does.

---

## 3) No layout changes required (but here’s the intended stack)

### `application.html.erb`

* Global header (only global)
* Main content

### `teller.html.erb`

* Global header (only global)
* Teller topbar (context)
* Teller command bar (commands)
* Main content

---

## Optional refinement (still DROP-IN SAFE)

If you want to prevent the global header from rendering on unauthenticated pages, keep your existing:

```erb
<% if authenticated? %>
  <div class="sticky top-0 z-50">
    <%= render "shared/global_header" %>
  </div>
<% end %>
```

If you want the global header always present but showing “Sign in” when unauthenticated, say so and I’ll adjust the partial accordingly.

---

