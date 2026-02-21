## Plan: Cohesive Teller View Ownership (DRAFT)

Great direction. With your choices, this pass will do a full docs-aligned partial split while keeping one minimal global indicator (Session badge) in the app header. The goal is to eliminate repeated context blocks, make ownership explicit (global chrome vs teller shell vs page body), and give every teller page the same visual rhythm as the mockup/docs.

**Steps**
1. Define ownership contract in code structure: global app header owns brand/nav + one session badge; teller shell owns teller operational context (teller/branch/workstation/session/time); page body owns task-specific UI.
2. Introduce docs-aligned teller shared partials under [app/views/teller/shared/](app/views/teller/shared/) and migrate repeated sections out of [app/views/teller/dashboard/_posting_workspace.html.erb](app/views/teller/dashboard/_posting_workspace.html.erb) and page templates.
3. Refactor teller pages to compose the same shell + zone sequence (topbar, page header, entry zone, reference zone, totals, cash footer, approval, receipt) in [app/views/teller/dashboard/index.html.erb](app/views/teller/dashboard/index.html.erb), [app/views/teller/contexts/show.html.erb](app/views/teller/contexts/show.html.erb), and [app/views/teller/transaction_pages/show.html.erb](app/views/teller/transaction_pages/show.html.erb).
4. Remove duplication at source:
- drop branch/workstation/teller badges from teller page bodies where topbar already shows them,
- remove duplicate Page Header in workspace partial so each page has a single header owner,
- keep only the global session badge in [app/views/layouts/application.html.erb](app/views/layouts/application.html.erb).
5. Re-map existing dashboard partials to new shared ownership:
- [app/views/teller/dashboard/_top_context_bar.html.erb](app/views/teller/dashboard/_top_context_bar.html.erb) becomes/shared topbar source,
- [app/views/teller/dashboard/_session_context_card.html.erb](app/views/teller/dashboard/_session_context_card.html.erb) and [app/views/teller/dashboard/_teller_session_card.html.erb](app/views/teller/dashboard/_teller_session_card.html.erb) stay context-page specific,
- posting shell fragments are extracted from [app/views/teller/dashboard/_posting_workspace.html.erb](app/views/teller/dashboard/_posting_workspace.html.erb).
6. Ensure Stimulus targets/actions still bind after partial moves, centered on [app/javascript/controllers/posting_form_controller.js](app/javascript/controllers/posting_form_controller.js), [app/javascript/controllers/reference_panel_controller.js](app/javascript/controllers/reference_panel_controller.js), and [app/javascript/controllers/approval_panel_controller.js](app/javascript/controllers/approval_panel_controller.js).
7. Update/extend tests for rendering and route/page expectations in [test/controllers/teller/](test/controllers/teller/) and relevant system coverage in [test/system/](test/system/), especially for “single source of context” on teller pages.

**Verification**
- bin/rubocop
- bin/rails test
- RAILS_ENV=test bin/rails test:system
- Manual check: each teller page has one topbar context source, one page header, no duplicated branch/workstation/session blocks in body.

**Decisions**
- Scope: Full docs-aligned partial split in this pass.
- Global header on teller pages: keep only Session badge.
- Teller context visibility: owned by teller shell/topbar, not repeated in page body.
