# Owner Edition MVP — Acceptance Contract

**Milestone:** Android-first commercial release
**Scope:** One owner/admin can run an ordinary small business without a parallel paper ledger or another bookkeeping app.

## Delivery status (source audit, 2026-09-29)

This contract states the *required release behavior*. It is not a list of shipped features. At `main` `a8b5080`, none of the 14 flows below is complete end to end. The current source supports parts of six flows; eight have no usable end-to-end path. CI at `9580c00` passed Flutter tests and a debug APK build, but that does not establish commercial release readiness or device behavior at the current head. The most recent recorded physical-device evidence covers older builds; it must not be used to qualify newer UI.

| Flow | Status | What the current source actually supports / gap |
| --- | --- | --- |
| 1. First launch, tour, authentication | Partial | Welcome screen exists; tour and login controls are disabled. |
| 2. Account and business setup | Partial | Local workspace creation exists; account sign-in and authentication do not. |
| 3. Product or service setup | Partial | Product entry with price and optional cost exists; it has no widget test and is not connected to sale selection. A distinct service setup flow is absent. |
| 4. Fast sale | Partial | Manual line entry, totals, payment and local save have tests and older device evidence; selecting a saved product or service is absent. |
| 5. Service or agent transaction | No usable path | A transaction type exists, but no dedicated entry flow with recipient/reference fields is present. |
| 6. Customer payment | No usable path | A payment type and balance calculation exist, but no payment entry flow updates a customer's balance. |
| 7. Expense | Partial | Expense/purchase entry screens are reachable from the workspace; no widget or device evidence qualifies the complete flow. |
| 8. Customer/supplier ledger | No usable path | Customer list/detail and a calculated open balance exist, but sales cannot attach a customer through the UI; supplier ledger behavior is absent. |
| 9. Return or refund | No usable path | No reference-based reversal/adjustment flow exists. |
| 10. Receipt or invoice | No usable path | A text share sheet exists, but the transaction details page passes it an empty transaction, so it cannot produce a valid receipt for that sale. PDF, print and document numbering are absent. |
| 11. Dashboard | Partial | Today's local summary and recent transactions exist; the full specified breakdown and linked cost/profit workflow are absent. |
| 12. Reports | No usable path | Exporting raw user data exists; daily/monthly/yearly/custom business reports do not. |
| 13. Day closing | No usable path | No expected-versus-actual cash closing flow exists. |
| 14. Backup or sync | No usable path | Local JSON export exists; authenticated cross-device persistence and restore do not. |

Status here means *whole acceptance flow*, not whether a model, screen, or isolated test exists. Change a row to complete only after its entry-to-result path, persistence/financial invariants, relevant CI checks, and current-build device evidence are recorded. See `RELEASE_GATES.md` and `PHYSICAL_DEVICE_VALIDATION.md` for component and device evidence.

## P0 release flows

1. First launch → welcome/tour → optional skip → authentication.
2. Sign in/create account → create business → choose business type → minimal setup → dashboard.
3. Create product/service → optionally configure private cost and selling price → save.
4. Fast sale → select product/service → quantity/amount → complete.
5. Service/agent transaction → select service → transaction amount → optional customer/contact/reference → complete.
6. Customer payment → record amount and method → automatically update due/balance.
7. Expense → quick entry → update business result/cash.
8. Customer/supplier ledger → view balance and history.
9. Returns/refunds → reference original transaction → controlled reversal/adjustment.
10. Receipt/invoice → generate appropriate document → preview → share/print/save.
11. Dashboard → today's activity, sales/service value, gross profit where cost is known, expenses, receivables, cash summary.
12. Reports → daily/monthly/yearly/custom range with product/service/commission breakdown.
13. Closing → expected cash → actual cash → variance → close day.
14. Backup/sync → authenticated business data persists beyond the device.

## Mandatory vs optional input

A normal transaction must require only the minimum information needed for a valid record. Customer identity, mobile number, external reference, note, discount, and other enrichment fields must remain optional unless a specific business rule makes one necessary.

The UI must use progressive disclosure. Advanced fields live behind `More details` rather than blocking the fast path.

## Financial invariants

- Selling price is customer-facing.
- Actual cost/cost basis is private.
- Profit/margin is derived and private.
- Historical posted transactions retain the cost basis used for their calculation.
- Returns/refunds affect the original financial meaning and remain auditable.
- Financial calculations are deterministic and use precise money representation.
- Posted records are not silently hard-deleted.

## Document invariants

Every posted transaction receives a stable unique identifier. The document type is selected from transaction/business context, for example receipt, invoice, service receipt, job card, quotation, or delivery document.

Customer-facing documents must never reveal private cost, internal margin, or confidential business notes.

## Business coverage for first release

The configuration must cover at minimum:

- general/grocery retail
- super shop
- pharmacy
- garments/fashion
- electronics/mobile
- hardware/building materials
- cosmetics
- furniture
- restaurant/cafe
- wholesale
- distributor
- service business
- online/F-commerce seller
- freelancer/professional
- MFS/recharge/Flexiload/local digital service shop
- computer service/printing/photocopy/scan/typing/online service center
- other configurable business

The release does not need a unique screen for every category. It needs a shared transaction engine with category-specific defaults and recommendations.

## Deferred

Staff accounts/roles, public storefront/customer accounts, advanced collaboration, official MFS integrations, AI assistant, and broad accounting/tax features are deferred until Owner Edition usage validates them.

## Release quality bar

The app is not ready for commercial handoff if the fast sale path is slow or confusing, if private cost can leak into customer/public documents, if a normal business cannot record its daily transactions without external paper/software, or if a sync retry can duplicate a financial transaction.
