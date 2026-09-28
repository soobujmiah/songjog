# Songjog Platform Architecture

## Purpose

Songjog is an adaptive, relationship-aware platform for businesses, service providers, institutions, staff, customers, students, trainees, guardians and other permitted participants.

The first commercial release is the Owner Edition. The architecture must support future two-sided participant experiences without forcing those features into the first release.

## Core layers

```text
Presentation
  -> Workspace + Role-aware UI
  -> Bengali / English localization
  -> Accessibility + motion system

Application
  -> Onboarding
  -> Transactions
  -> Payments / Due
  -> Documents
  -> Relationships
  -> Reports
  -> Entitlement

Domain
  -> Business / Institution
  -> Person / Account
  -> Product / Service
  -> Program / Trade / Batch
  -> Transaction / Payment
  -> Document
  -> Relationship / Permission

Infrastructure
  -> Local persistence
  -> Sync
  -> Authentication
  -> Entitlement service
  -> Backup / Export
```

## Identity and relationships

A person has one platform identity. A relationship grants contextual participation:

- Owner -> business/institution
- Staff -> business/institution
- Teacher/Trainer -> institution/program
- Student/Trainee -> institution/program/batch
- Guardian -> student
- Customer/Client -> business/service
- Supplier -> business

Relationships do not grant unrestricted access. Visibility is derived from role, workspace and relationship permissions.

## Workspace adaptation

The account's workspace profile determines which workflows appear. The same financial core can power:

- General retail
- Service businesses
- MFS/recharge
- Printing/photocopy
- Computer/mobile service
- Restaurant
- Pharmacy
- Wholesale
- Online business
- Education/training institutions
- Medical/health training institutions
- Technical training institutions

Institution type and Trade/Course/Program are separate entities. Institutions define their own programs/trades rather than relying on a fixed global list.

## Financial invariants

- Money is stored as integer minor units; no binary floating-point currency storage.
- A posted transaction is immutable in audit history. Corrections use return, refund or adjustment records.
- Customer-facing documents never expose actual cost, margin or internal notes.
- Optional participant accounts must never be required for a basic sale/service unless the configured workflow explicitly requires identity.
- Offline records must be durable and safely reconciled when online.

## Participant-facing expansion

Future participant features include:

- Customer service/order history
- Customer receipts and invoices
- Student fee history and receipts
- Guardian/student relationship views
- Notices, results, certificates and testimonials
- Staff salary statements
- Institution communications

These are separate permissioned surfaces over the same underlying identity and document/transaction infrastructure.

## Security boundary

For a commercial release, the public repository and APK must contain no production secrets. Commercial entitlement must be server-authoritative. Platform Owner status must be a backend role, never a hard-coded master password/code in the application. These are architecture requirements, not claims that the backend or entitlement system exists today; see `MVP_ACCEPTANCE.md` and `RELEASE_GATES.md` for current delivery status.
