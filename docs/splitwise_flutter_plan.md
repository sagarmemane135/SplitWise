# SplitEase-like Flutter App Plan (No Backend + Optional P2P)

## Goals
- Build an offline-first Flutter mobile app for group expense tracking.
- No backend dependency.
- Optional real-time collaboration via peer-to-peer session.

## Feature Inventory

### 1. Core purpose
- Group expense tracking.
- Automatic per-member balances.
- Debt simplification into minimum settlement payments.

### 2. Group management
- Create/select/delete multiple groups.
- Active group selection.
- Delete confirmation modal.
- Empty-state onboarding when no group exists.

### 3. Member and identity management
- Add/remove members.
- Block member deletion if used by any expense/comment reference.
- Select current identity for current device session.
- Block duplicate names (case-insensitive).
- Roles: Admin and Member.

### 4. Expense management
- Create/edit/delete expense.
- Expense fields: title, total, payers, participants, split method, date, createdBy, comments.
- Split methods: equal, fixed amount, percentage.
- Validation:
  - Required fields.
  - At least one payer and one participant.
  - Sum(payers) == total.
  - Amount split sum == total.
  - Percentage split sum == 100.
- Edit/delete only by admin or expense creator.

### 5. Comments
- Comment thread per expense.
- Comment includes author name, text, timestamp.
- Requires selected identity.

### 6. Financial outputs
- Member summary: gets back / owes.
- Simplified debts via greedy algorithm.
- Floating-point tolerance handling.

### 7. Collaboration (P2P)
- Host creates session id.
- Join by manual id, deep link, or share link.
- Join request requires name that already exists in group.
- Clear rejection reasons.
- Initial full snapshot sync and assigned identity sync.
- Incremental live updates: group, comments, presence.
- Active collaborator list + connection status and peer count.
- Reliability: STUN config, timeout, error handling, reconnect.
- Guest restrictions in collaboration mode.

### 8. PDF export
- PDF report for active group.
- Sections: summary cards, final balances, settlement plan, expense breakdown.
- Multi-page support.
- Date range, totals, member count.

### 9. Persistence and reset
- Local persistence for device id, groups, active group id.
- Full reset flow with confirmation.

### 10. UX structure
- Bottom navigation: Expenses, Shares, Add, Debts, Manage.
- Manage page: group actions, identity, collaborate, download, install, reset.
- Safety UX: destructive confirmations, disabled action reasons, collaboration tips.

### 11. PWA/offline
- Installable web app support.
- Service worker and shell cache.
- Offline fallback route.
- Install prompt/button.

## Architecture
- State: Riverpod.
- Routing: go_router + deep links.
- Local DB: Hive or Isar.
- P2P transport: flutter_webrtc data channels.
- PDF: pdf + printing.

Layering:
- Presentation layer: pages, widgets, controllers/providers.
- Domain layer: entities, rules, use cases.
- Data layer: local storage, p2p protocol, repository implementations.

## Delivery Phases
1. Foundation setup + navigation + storage.
2. Groups/members/identity + role constraints.
3. Expense + split engine + validation.
4. Balances + simplified debts.
5. Collaboration P2P + snapshot/events/presence.
6. PDF export + PWA polish.
7. Testing + hardening.

## Proposed Folder Structure

- lib/app
- lib/bootstrap
- lib/core/constants
- lib/core/errors
- lib/core/utils
- lib/core/widgets
- lib/data/local/datasources
- lib/data/local/models
- lib/data/p2p/models
- lib/data/p2p/protocol
- lib/data/p2p/transport
- lib/data/repositories
- lib/domain/entities
- lib/domain/repositories
- lib/domain/services
- lib/domain/usecases
- lib/features/onboarding
- lib/features/groups
- lib/features/members
- lib/features/identity
- lib/features/expenses
- lib/features/shares
- lib/features/debts
- lib/features/manage
- lib/features/collaboration
- lib/features/export_pdf
- lib/features/settings_reset

Feature module convention:
- feature/data
- feature/domain
- feature/presentation/pages
- feature/presentation/widgets
- feature/presentation/providers
